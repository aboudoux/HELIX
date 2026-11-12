async (page) => {
  await page.bringToFront();
  const before = await page.evaluate(() => window.helixDiagnostics);
  await page.mouse.move(660, 420);
  await page.waitForTimeout(500);
  await page.screenshot({path: 'output/playwright/web-running-first.png'});
  return {before, after: await page.evaluate(() => window.helixDiagnostics)};
}
