# Draft upstream report: CanvasKit startup null check (not yet filed)

Not filed because there is no minimal reproduction: a plain `flutter create`
counter app, built and loaded under the same conditions, gave **0 errors in
160 loads** (with and without COOP/COEP). File it once a small app
reproduces it; the stress job `engine-race-minimal` in
`.github/workflows/stress.yml` is the harness for trying one.

## What we see

- Flutter 3.44.2 (engine 77e2e94772b6eb43759e34ed1ad7da4674e19cab), web
  release build, dart2js + CanvasKit (Firefox is not on the wasm allow list).
- Firefox without WebGL, so CanvasKit logs "Falling back to CPU-only
  rendering. Reason: webGLVersion is -1".
- Under CPU starvation (all browsers pinned to one core with a busy loop),
  an uncaught `Null check operator used on a null value` appears around the
  first frames. It happened in 9 of 80 loads of our app *before* any of our
  web changes, and 3 of 80 after; on an unloaded machine it is rare.
- The app keeps working.

## Symbolized stack (source maps)

The reported stack is where the error surfaced, not where it was thrown:

```
Error._throw                                   core_patch.dart:293
Error.throwWithStackTrace                      errors.dart:120
_rootHandleError.<anonymous function>          zone_root.dart:22
_microtaskLoop                                 schedule_microtask.dart:119
...
_AsyncCompleter.complete                       future_impl.dart:98
CkSurface._initialize                          canvaskit/surface.dart:89
CkSurface                                      canvaskit/surface.dart:19
CkOnscreenSurface                              canvaskit/surface.dart:303
SurfaceProvider.createSurface                  compositing/surface.dart:20
MultiSurfaceRasterizer.createPictureToImageSurface
                                               compositing/multi_surface_rasterizer.dart:52
CanvasKitRenderer.initialize.<anonymous function>
                                               canvaskit/renderer.dart:522
CanvasKitRenderer.initialize                   canvaskit/renderer.dart:63
```

So something awaiting `CkSurface.initialized` on the picture-to-image surface
hits a `!` on null, most likely racing the first frame when the CPU is
starved.

## Reproduce (our app)

`tool/web_live_test/stress/startup-race.spec.mjs` with
`taskset -c 0` on the browsers and a busy loop on the same core; see the
`race` job history in the bisect notes of REMAINING_WORK.md.
