# moui_3d

Experimental, renderer-neutral 3D scene and glTF viewer primitives for MoUI.

The first slice intentionally owns CPU scene data, camera controls, picking,
and the external-surface binding contract. It does not add 3D variants to
MoUI's 2D `DrawCommand` protocol.
