async (page) => {
  const state=()=>page.evaluate(()=>window.helixDiagnostics);
  const history=[];
  await page.bringToFront();
  let d=await state();
  let mx=640,my=625;
  await page.mouse.click(mx,my);
  await page.waitForTimeout(1000);
  const wrap=x=>Math.atan2(Math.sin(x),Math.cos(x));
  async function turn(yaw,pitch=0) {
    for(let i=0;i<3;i++) {
      d=await state();
      const dx=-wrap(yaw-d.yaw)/.00225;
      const dy=-(pitch-d.pitch)/.00225;
      if(Math.abs(dx)<1 && Math.abs(dy)<1)break;
      mx+=dx; my+=dy;
      await page.mouse.move(mx,my);
      await page.waitForTimeout(240);
    }
  }
  await turn(0,0);
  history.push({step:'look-forward',state:await state()});
  await page.keyboard.down('w');
  await page.waitForTimeout(1800);
  await page.keyboard.up('w');
  await page.waitForTimeout(500);
  history.push({step:'first-sector-entered',state:await state()});
  await page.screenshot({path:'output/playwright/web-enemies.png'});
  const fps=[];
  for(let i=0;i<18;i++) {
    d=await state();
    if(d.finished || d.paused)break;
    fps.push({fps:d.fps,draw_calls:d.draw_calls,objects:d.objects,health:d.health,enemies:d.enemies.length});
    const enemy=d.enemies.slice().sort((a,b)=>Math.hypot(a.position[0]-d.position[0],a.position[2]-d.position[2])-Math.hypot(b.position[0]-d.position[0],b.position[2]-d.position[2]))[0];
    if(!enemy)break;
    const dx=enemy.position[0]-d.position[0], dz=enemy.position[2]-d.position[2];
    const ey=enemy.position[1]+(enemy.name.includes('04')?.8:.25);
    const pitch=Math.atan2(ey-(d.position[1]+1.65),Math.hypot(dx,dz));
    await turn(Math.atan2(-dx,-dz),pitch);
    if(d.ammo<3) {await page.keyboard.press('r'); await page.waitForTimeout(2000);}
    await page.mouse.down();
    await page.waitForTimeout(450);
    await page.mouse.up();
    await page.waitForTimeout(250);
    history.push({step:'combat-'+i,state:await state()});
    if((await state()).destroyed>=2)break;
  }
  await page.screenshot({path:'output/playwright/web-combat.png'});
  const result=await state();
  await page.keyboard.press('Escape');
  await page.waitForTimeout(350);
  return {history,fps,result};
}
