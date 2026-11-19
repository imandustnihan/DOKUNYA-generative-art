{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {canvasKitBaseUrl: new URL('canvaskit/',document.baseURI).href, fontFallbackBaseUrl: new URL('assets/fonts/fallback/',document.baseURI).href},
  onEntrypointLoaded: async function(initializer) {
    const runner=await initializer.initializeEngine();
    document.getElementById('loading')?.remove();
    await runner.runApp();
    if('serviceWorker' in navigator) {
      navigator.serviceWorker.register(new URL('artpulse_sw.js',document.baseURI)).catch(()=>{});
    }
  }
});
