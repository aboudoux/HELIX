async (page) => {
  const runs=[];
  const quantile=(v,p)=>{const s=v.slice().sort((a,b)=>a-b);return s[Math.min(s.length-1,Math.floor(s.length*p))];};
  await page.setViewportSize({width:1280,height:800});
  for(const culling of ['off','on','off','on','off','on']) {
    await page.bringToFront();
    await page.goto('http://127.0.0.1:8765/?diagnostics=1&profile=1&culling='+culling);
    await page.waitForFunction(()=>window.helixFrameSamples?.length>40);
    let d=await page.evaluate(()=>window.helixDiagnostics);
    const box=await page.locator('canvas').boundingBox(),[x,y,w,h]=d.resume_rect;
    await page.mouse.click(box.x+(x+w/2)*box.width/d.viewport[0],box.y+(y+h/2)*box.height/d.viewport[1]);
    await page.waitForTimeout(4000);
    const initial=await page.evaluate(()=>({last:window.helixFrameSamples.at(-1)[0],state:window.helixDiagnostics}));
    await page.waitForTimeout(6000);
    const end=await page.evaluate(last=>({samples:window.helixFrameSamples.filter(x=>x[0]>last),state:window.helixDiagnostics}),initial.last);
    const v=end.samples.map(x=>x[1]);
    runs.push({culling,initial:initial.state,final:end.state,samples:end.samples,
      valid:!end.state.paused && initial.state.yaw===0 && end.state.yaw===0 && initial.state.pitch===0 && end.state.pitch===0 && end.state.position[2]===64,
      summary:{frames:v.length,mean_ms:v.reduce((a,b)=>a+b,0)/v.length,p50_ms:quantile(v,.5),p95_ms:quantile(v,.95),p99_ms:quantile(v,.99),over33_ms:v.filter(x=>x>33.33).length,calls_p50:quantile(end.samples.map(x=>x[2]),.5),process_p50_ms:quantile(end.samples.map(x=>x[3]),.5),physics_p50_ms:quantile(end.samples.map(x=>x[4]),.5)}});
    await page.screenshot({path:'output/playwright/perf-view-'+culling+'.png'});
    await page.keyboard.press('Escape');
  }
  return {runs,browser:await page.evaluate(()=>navigator.userAgent)};
}
