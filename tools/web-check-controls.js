async (page) => {
  const checks = [];
  const record = (name, pass, details) => checks.push({name, pass: !!pass, details});
  const state = () => page.evaluate(() => window.helixDiagnostics);
  const settle = () => page.waitForTimeout(350);
  async function resume() {
    await page.bringToFront();
    const d = await state();
    const box = await page.locator('canvas').boundingBox();
    const [x,y,w,h] = d.resume_rect;
    await page.mouse.click(box.x+(x+w/2)*box.width/d.viewport[0],box.y+(y+h/2)*box.height/d.viewport[1]);
    await page.waitForTimeout(1000);
  }
  await page.context().addInitScript(() => {
    window.helixAudioQA = {contexts: [], analysers: [], peak: 0};
    const original = AudioNode.prototype.connect;
    AudioNode.prototype.connect = function (target, ...args) {
      const result = original.call(this, target, ...args);
      if (target instanceof AudioDestinationNode) {
        const analyser = this.context.createAnalyser();
        original.call(this, analyser);
        window.helixAudioQA.contexts.push(this.context);
        window.helixAudioQA.analysers.push(analyser);
      }
      return result;
    };
    setInterval(() => {
      for (const analyser of window.helixAudioQA.analysers) {
        const values = new Float32Array(analyser.fftSize);
        analyser.getFloatTimeDomainData(values);
        for (const v of values) window.helixAudioQA.peak = Math.max(window.helixAudioQA.peak, Math.abs(v));
      }
    }, 20);
  });
  await page.bringToFront();
  await page.reload();
  await page.waitForFunction(() => window.helixDiagnostics?.scene, {timeout: 60000});
  await page.waitForTimeout(1500);
  await page.screenshot({path: 'output/playwright/web-menu-final.png'});
  const initial = await state();
  record('campaign menu + JSON layout loaded', initial.stage===0 && initial.health===100 && initial.paused, initial);
  await resume();
  let d = await state();
  record('start and actual browser pointer lock', !d.paused && await page.evaluate(()=>!!document.pointerLockElement), d);
  const beforeLook=d;
  await page.mouse.move(650,410);
  await settle();
  d=await state();
  record('mouse look changes heading', d.yaw!==beforeLook.yaw || d.pitch!==beforeLook.pitch, {before:beforeLook.yaw,after:d.yaw,pitch:d.pitch});
  const origin=d.position;
  await page.keyboard.down('w');
  await page.waitForTimeout(900);
  await page.keyboard.up('w');
  await settle();
  d=await state();
  record('keyboard movement', Math.hypot(d.position[0]-origin[0],d.position[2]-origin[2])>2, {origin,position:d.position});
  await page.keyboard.down('Shift');
  await page.keyboard.down('w');
  await settle();
  d=await state();
  record('sprint',d.sprinting,d.position);
  await page.keyboard.up('w');
  await page.keyboard.up('Shift');
  await page.keyboard.down('Control');
  await settle();
  record('crouch',(await state()).crouching);
  await page.keyboard.up('Control');
	await page.waitForTimeout(450);
  await page.keyboard.press('Space');
  await settle();
  record('jump',(await state()).position[1]>.2,(await state()).position);
  await page.waitForTimeout(600);
  await page.mouse.down({button:'right'});
  await settle();
  record('right click aiming, no browser menu',(await state()).aim>.9);
  await page.screenshot({path:'output/playwright/web-aim.png'});
  await page.mouse.up({button:'right'});
  await settle();
  await page.mouse.down();
  await page.waitForTimeout(700);
  await page.mouse.up();
  await settle();
  const fired=await state();
  record('held fire consumes ammunition',fired.ammo<30 && fired.ammo>20,fired.ammo);
  const audio=await page.evaluate(()=>({peak:window.helixAudioQA.peak,contexts:window.helixAudioQA.contexts.map(x=>({state:x.state,rate:x.sampleRate})),analysers:window.helixAudioQA.analysers.length}));
  record('actual WebAudio output after user gesture',audio.peak>0 && audio.contexts.some(x=>x.state==='running'),audio);
  await page.keyboard.press('r');
  await settle();
  record('reload starts',(await state()).reloading);
  await page.screenshot({path:'output/playwright/web-reload.png'});
  await page.keyboard.press('Escape');
  await settle();
  d=await state();
  record('Escape pauses and releases pointer',d.paused && !await page.evaluate(()=>!!document.pointerLockElement),d);
  await page.waitForTimeout(1000);
  record('reload remains frozen during pause',(await state()).reloading);
  await resume();
  record('resume button recaptures and unpauses',!(await state()).paused && await page.evaluate(()=>!!document.pointerLockElement));
  await page.waitForTimeout(2000);
  d=await state();
  record('reload finishes after resume',d.ammo===30 && !d.reloading,d.ammo);
  await page.evaluate(()=>document.exitPointerLock());
  await page.waitForTimeout(1100);
  record('browser unlock without key pauses',(await state()).paused);
  await resume();
  const other=await page.context().newPage();
  await other.goto('about:blank');
  await other.bringToFront();
  await page.waitForTimeout(1000);
  await page.bringToFront();
  await settle();
  record('focus loss pauses',(await state()).paused);
  await other.close();
  await resume();
  const performance=[];
  for(let i=0;i<12;i++) { await page.waitForTimeout(300); performance.push(await state()); }
  await page.screenshot({path:'output/playwright/web-quay.png'});
  await page.keyboard.press('Escape');
  await settle();
  await page.screenshot({path:'output/playwright/web-pause.png'});
  return {checks,passed:checks.filter(x=>x.pass).length,total:checks.length,performance,
    load:await page.evaluate(()=>performance.getEntriesByType('resource').map(x=>({name:x.name,duration:x.duration,bytes:x.transferSize}))),
    browser:await page.evaluate(()=>navigator.userAgent)};
}
