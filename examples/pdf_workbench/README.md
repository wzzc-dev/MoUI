# PDF Workbench

PDF Workbench is a native Skia PDF reader/editor prototype. The shared app uses
injected document and raster services so app-level checks can run without
linking PDFium.

## PDFium Prebuild

The PDFium prebuild is disabled by default. Ordinary app, protocol,
native-transport, and Web checks should not download PDFium.

```sh
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdfium_adapter --target native
```

The `pdfium_adapter` test still passes in the default stub mode and reports the
raster service as unavailable.

Enable the locked PDFium prebuild only when validating real PDFium
rasterization:

```sh
MOUI_PDFIUM_ENABLE_PREBUILD_PDFIUM=1 moon test examples/pdf_workbench/pdfium_adapter --target native
MOUI_PDFIUM_ENABLE_PREBUILD_PDFIUM=1 moon build examples/pdf_workbench/macos_skia --target native
```

To use an existing local PDFium install without downloading the locked
prebuild, provide both paths:

```sh
MOUI_PDFIUM_INCLUDE=/path/to/pdfium/include \
MOUI_PDFIUM_LIB_DIR=/path/to/pdfium/lib \
moon test examples/pdf_workbench/pdfium_adapter --target native
```

`MOUI_PDFIUM_LINK_MODE=auto|dynamic|static` controls the PDFium link mode when
PDFium is enabled. `MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1` remains supported as
an explicit opt-out and takes precedence over the enable variable.

The real-raster smoke script opts in automatically:

```sh
node scripts/pdf-workbench-native-smoke.mjs
```
