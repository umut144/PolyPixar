#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

namespace godot {

class PolyToolsCDT : public RefCounted {
    GDCLASS(PolyToolsCDT, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary triangulate(
            const PackedVector2Array &p_vertices,
            const PackedInt32Array &p_constraint_edges) const;
};

} // namespace godot
