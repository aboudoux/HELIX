async (page) => {
  const state=()=>page.evaluate(()=>window.helixDiagnostics);
  const history=[];
  await page.bringToFront();
  let mx=640,my=625;
  await page.mouse.click(mx,my);
  await page.waitForTimeout(1000);
  const wrap=x=>Math.atan2(Math.sin(x),Math.cos(x));
  async function turn(yaw,pitch=0) {
    for(let i=0;i<3;i++) {
      const d=await state();
      const dx=-wrap(yaw-d.yaw)/.00225,dy=-(pitch-d.pitch)/.00225;
      if(Math.abs(dx)<1 && Math.abs(dy)<1)break;
      mx+=dx;my+=dy;await page.mouse.move(mx,my);await page.waitForTimeout(240);
    }
  }
  async function fight(attempts) {
    for(let i=0;i<attempts;i++) {
      const d=await state();if(d.finished || !d.enemies.length)break;
      if(d.ammo<4){await page.keyboard.press('r');await page.waitForTimeout(2000);}
      const enemy=d.enemies.slice().sort((a,b)=>Math.hypot(a.position[0]-d.position[0],a.position[2]-d.position[2])-Math.hypot(b.position[0]-d.position[0],b.position[2]-d.position[2]))[0];
      const dx=enemy.position[0]-d.position[0],dz=enemy.position[2]-d.position[2];
      await turn(Math.atan2(-dx,-dz),Math.atan2(enemy.position[1]+(enemy.name.includes('04')?.7:.25)-d.position[1]-1.65,Math.hypot(dx,dz)));
      await page.mouse.down();await page.waitForTimeout(450);await page.mouse.up();await page.waitForTimeout(250);
      history.push({step:'fight',state:await state()});
    }
  }
  async function walk(x,z) {
    for(let i=0;i<16;i++){
      const d=await state();if(d.finished)return false;
      const dx=x-d.position[0],dz=z-d.position[2],distance=Math.hypot(dx,dz);
      if(distance<1)return true;
      await turn(Math.atan2(-dx,-dz));
      await page.keyboard.down('w');await page.waitForTimeout(Math.min(750,distance/6*1000));await page.keyboard.up('w');await page.waitForTimeout(250);
      const after=await state();
      if(Math.hypot(after.position[0]-d.position[0],after.position[2]-d.position[2])<.3){history.push({step:'blocked',target:[x,z],state:after});return false;}
    }
    return false;
  }
  await fight(6);
  history.push({step:'remaining-clear',state:await state()});
  if(!(await state()).finished){
    const route=[[-50,47],[-37,47],[-37,38],[-50,38],[-52,33]];
    for(const [x,z] of route){const reached=await walk(x,z);history.push({step:'walk',target:[x,z],reached,state:await state()});if(!reached)break;}
    await fight(5);
    await page.keyboard.press('e');await page.waitForTimeout(1500);
  }
  await page.screenshot({path:'output/playwright/web-relay-attempt.png'});
  const result=await state();
  await page.keyboard.press('Escape');await page.waitForTimeout(350);
  return {history,result};
}
