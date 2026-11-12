async (page) => {
  const gpu=await page.evaluate(()=>{
    const gl=document.querySelector('canvas').getContext('webgl2');
    const ext=gl.getExtension('WEBGL_debug_renderer_info');
    return {vendor:gl.getParameter(ext.UNMASKED_VENDOR_WEBGL),renderer:gl.getParameter(ext.UNMASKED_RENDERER_WEBGL),size:[gl.drawingBufferWidth,gl.drawingBufferHeight]};
  });
  await page.goto('http://127.0.0.1:8765/');
  await page.waitForTimeout(6000);
  const normal=await page.evaluate(()=>({diagnosticsExposed:typeof window.helixDiagnostics!=='undefined',title:document.title}));
  await page.screenshot({path:'output/playwright/web-ready.png'});
  return {gpu,normal};
}
