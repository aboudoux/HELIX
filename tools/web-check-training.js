async (page) => {
  await page.bringToFront();
  await page.reload();
  await page.waitForFunction(()=>window.helixDiagnostics?.started===false);
  await page.waitForTimeout(800);
  await page.mouse.click(640,707);
  await page.waitForFunction(()=>window.helixDiagnostics?.scene==='res://scenes/main.tscn');
  await page.waitForTimeout(800);
  const menu=await page.evaluate(()=>window.helixDiagnostics);
  await page.screenshot({path:'output/playwright/web-training-menu.png'});
  const box=await page.locator('canvas').boundingBox();
  const [x,y,w,h]=menu.resume_rect;
  await page.mouse.click(box.x+(x+w/2)*box.width/menu.viewport[0],box.y+(y+h/2)*box.height/menu.viewport[1]);
  await page.waitForTimeout(1200);
  const running=await page.evaluate(()=>({state:window.helixDiagnostics,lock:!!document.pointerLockElement}));
  await page.screenshot({path:'output/playwright/web-training.png'});
  await page.keyboard.press('Escape');
  await page.waitForTimeout(350);
  return {menu,running,pass:running.state.scene==='res://scenes/main.tscn'&&!running.state.paused&&running.lock};
}
