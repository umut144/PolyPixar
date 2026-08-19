#include "polytools_cdt.h"

#include <CDT.h>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <cmath>
#include <exception>
#include <set>
#include <utility>
#include <vector>

using namespace godot;

namespace {

Dictionary error_result(const String &p_message) {
    Dictionary result;
    Array errors;
    errors.push_back(p_message);
    result["valid"] = false;
    result["errors"] = errors;
    result["triangles"] = PackedInt32Array();
    result["fixed_edges"] = PackedInt32Array();
    result["diagnostics"] = Dictionary();
    return result;
}

} // namespace

void PolyToolsCDT::_bind_methods() {
    ClassDB::bind_method(
            D_METHOD("triangulate", "vertices", "constraint_edges"),
            &PolyToolsCDT::triangulate);
}

Dictionary PolyToolsCDT::triangulate(
        const PackedVector2Array &p_vertices,
        const PackedInt32Array &p_constraint_edges) const {
    if (p_vertices.size() < 3) {
        return error_result("CDT requires at least three vertices.");
    }
    if ((p_constraint_edges.size() % 2) != 0) {
        return error_result("Constraint edge data must contain index pairs.");
    }

    std::vector<CDT::V2d<double>> vertices;
    vertices.reserve(static_cast<std::size_t>(p_vertices.size()));
    std::set<std::pair<double, double>> unique_positions;
    for (int64_t i = 0; i < p_vertices.size(); ++i) {
        const Vector2 point = p_vertices[i];
        if (!std::isfinite(point.x) || !std::isfinite(point.y)) {
            return error_result("Vertex coordinates must be finite.");
        }
        const std::pair<double, double> key(point.x, point.y);
        if (!unique_positions.insert(key).second) {
            return error_result("Duplicate vertex coordinates are not allowed.");
        }
        vertices.emplace_back(point.x, point.y);
    }

    std::vector<CDT::Edge> edges;
    edges.reserve(static_cast<std::size_t>(p_constraint_edges.size() / 2));
    std::set<std::pair<int32_t, int32_t>> unique_edges;
    for (int64_t i = 0; i < p_constraint_edges.size(); i += 2) {
        int32_t a = p_constraint_edges[i];
        int32_t b = p_constraint_edges[i + 1];
        if (a < 0 || b < 0 || a >= p_vertices.size() || b >= p_vertices.size()) {
            return error_result("Constraint edge contains an invalid vertex index.");
        }
        if (a == b) {
            return error_result("Constraint edge endpoints must be distinct.");
        }
        if (a > b) {
            std::swap(a, b);
        }
        if (!unique_edges.insert(std::make_pair(a, b)).second) {
            return error_result("Duplicate constraint edges are not allowed.");
        }
        edges.emplace_back(
                static_cast<CDT::VertInd>(a), static_cast<CDT::VertInd>(b));
    }

    try {
        CDT::Triangulation<double> triangulation(
                CDT::VertexInsertionOrder::Auto,
                CDT::IntersectingConstraintEdges::NotAllowed,
                0.0);
        triangulation.insertVertices(vertices);
        triangulation.insertEdges(edges);
        triangulation.eraseSuperTriangle();

        PackedInt32Array triangle_indices;
        triangle_indices.resize(
                static_cast<int64_t>(triangulation.triangles.size() * 3));
        int64_t triangle_write = 0;
        for (const CDT::Triangle &triangle : triangulation.triangles) {
            for (const CDT::VertInd vertex : triangle.vertices) {
                const int64_t index = static_cast<int64_t>(vertex);
                if (index < 0 || index >= p_vertices.size()) {
                    return error_result("CDT returned an invalid triangle index.");
                }
                triangle_indices.set(triangle_write++, static_cast<int32_t>(index));
            }
        }

        PackedInt32Array fixed_edges;
        fixed_edges.resize(static_cast<int64_t>(triangulation.fixedEdges.size() * 2));
        int64_t edge_write = 0;
        for (const CDT::Edge &edge : triangulation.fixedEdges) {
            fixed_edges.set(edge_write++, static_cast<int32_t>(edge.v1()));
            fixed_edges.set(edge_write++, static_cast<int32_t>(edge.v2()));
        }

        Dictionary diagnostics;
        diagnostics["input_vertex_count"] = p_vertices.size();
        diagnostics["input_constraint_count"] = p_constraint_edges.size() / 2;
        diagnostics["triangle_count"] = triangle_indices.size() / 3;
        diagnostics["fixed_edge_count"] = fixed_edges.size() / 2;

        Dictionary result;
        result["valid"] = true;
        result["errors"] = Array();
        result["triangles"] = triangle_indices;
        result["fixed_edges"] = fixed_edges;
        result["diagnostics"] = diagnostics;
        return result;
    } catch (const std::exception &exception) {
        return error_result(String("CDT failed: ") + exception.what());
    } catch (...) {
        return error_result("CDT failed with an unknown native error.");
    }
}
