async (page) => {
  await page.bringToFront();
  await page.setViewportSize({width:1280,height:800});
  await page.goto('http://127.0.0.1:8765/?diagnostics=1&profile=1');
  await page.waitForFunction(()=>window.helixFrameSamples?.length>40);
  let d=await page.evaluate(()=>window.helixDiagnostics);
  let box=await page.locator('canvas').boundingBox();
  const [x,y,w,h]=d.resume_rect;
  await page.mouse.click(box.x+(x+w/2)*box.width/d.viewport[0],box.y+(y+h/2)*box.height/d.viewport[1]);
  await page.waitForTimeout(4000);
  const runs=[];
  const percentile=(values,p)=>{const s=values.slice().sort((a,b)=>a-b);return s[Math.min(s.length-1,Math.floor(s.length*p))];};
  for(const width of [1280,640,1280,640,1280,640]) {
    await page.setViewportSize({width,height:width*800/1280});
    await page.waitForTimeout(1800);
    const start=await page.evaluate(()=>({last:window.helixFrameSamples.at(-1)[0],state:window.helixDiagnostics}));
    await page.waitForTimeout(6000);
    const end=await page.evaluate(start=>({samples:window.helixFrameSamples.filter(x=>x[0]>start.last),state:window.helixDiagnostics,canvas:[document.querySelector('canvas').width,document.querySelector('canvas').height]}),start);
    const dt=end.samples.map(x=>x[1]);
    runs.push({width,canvas:end.canvas,initial:start.state,final:end.state,samples:end.samples,
      summary:{frames:dt.length,mean_ms:dt.reduce((a,b)=>a+b,0)/dt.length,p50_ms:percentile(dt,.5),p95_ms:percentile(dt,.95),p99_ms:percentile(dt,.99),over33_ms:dt.filter(x=>x>33.33).length,
        calls_p50:percentile(end.samples.map(x=>x[2]),.5),process_p50_ms:percentile(end.samples.map(x=>x[3]),.5),physics_p50_ms:percentile(end.samples.map(x=>x[4]),.5)}});
  }
  await page.setViewportSize({width:1280,height:800});
  await page.waitForTimeout(1200);
  await page.screenshot({path:'output/playwright/perf-fixed-view.png'});
  await page.keyboard.press('Escape');
  return {runs,browser:await page.evaluate(()=>navigator.userAgent)};
}
