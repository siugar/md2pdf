const fs = require("fs");
const path = require("path");

async function run() {
  const args = process.argv.slice(2);
  const htmlPath = args[0];
  const pdfPath = args[1];
  const browserPath = args[2];

  if (!htmlPath || !pdfPath) {
    console.error("Usage: node print-pdf.js <htmlPath> <pdfPath> [browserPath]");
    process.exit(1);
  }

  if (!fs.existsSync(htmlPath)) {
    console.error("HTML not found:", htmlPath);
    process.exit(1);
  }

  let chromium;
  try {
    ({ chromium } = require("playwright"));
  } catch (err) {
    console.error("Playwright not found. Please install it: npm install -g playwright");
    process.exit(1);
  }

  const fileUrl = "file:///" + htmlPath.replace(/\\/g, "/");
  const launchOptions = { headless: true };

  if (browserPath && browserPath.length > 0) {
    launchOptions.executablePath = browserPath;
  }

  const browser = await chromium.launch(launchOptions);
  const page = await browser.newPage({ viewport: { width: 794, height: 1122 } });

  await page.goto(fileUrl, { waitUntil: "networkidle" });
  await page.emulateMedia({ media: "print" });

  const pxPerInch = 96;
  const pageWidthIn = 8.27;
  const pageHeightIn = 11.69;
  const marginRatio = 0.1;
  const marginLeftIn = pageWidthIn * marginRatio;
  const marginRightIn = pageWidthIn * marginRatio;
  const marginTopIn = pageHeightIn * marginRatio;
  const marginBottomIn = pageHeightIn * marginRatio;
  const inToMm = 25.4;
  const printableWidthPx = (pageWidthIn * pxPerInch) - ((marginLeftIn + marginRightIn) * pxPerInch);
  const printableHeightPx = (pageHeightIn * pxPerInch) - ((marginTopIn + marginBottomIn) * pxPerInch);
  const fullpageThresholdRatio = 0.5;
  const marginLeftMm = marginLeftIn * inToMm;
  const marginRightMm = marginRightIn * inToMm;
  const marginTopMm = marginTopIn * inToMm;
  const marginBottomMm = marginBottomIn * inToMm;

  await page.evaluate(async ({ thresholdRatio, printableWidthPx, printableHeightPx }) => {
    const waitImages = async () => {
      const images = Array.from(document.images || []);
      if (images.length === 0) {
        return;
      }

      await Promise.all(images.map((img) => {
        if (img.complete && img.naturalWidth > 0) {
          return Promise.resolve();
        }
        return new Promise((resolve) => {
          img.addEventListener("load", () => resolve(), { once: true });
          img.addEventListener("error", () => resolve(), { once: true });
        });
      }));
    };

    await waitImages();

    const fullHeightPx = printableHeightPx;
    const diagrams = document.querySelectorAll("img.mermaid-diagram");

    diagrams.forEach((img) => {
      const naturalWidth = img.naturalWidth || 0;
      const naturalHeight = img.naturalHeight || 0;
      const scale = naturalWidth > 0 ? (printableWidthPx / naturalWidth) : 1;
      const scaledHeight = naturalHeight * scale;
      shouldFullpage = img.classList.contains("mermaid-fullpage")
        || scaledHeight >= (fullHeightPx * thresholdRatio);

      shouldFullpage = true;
      if (shouldFullpage) {
        const wrapper = img.closest(".mermaid-wrap");

        if (wrapper) {
          wrapper.classList.add("mermaid-fullpage-wrap");
          wrapper.style.height = `${fullHeightPx}px`;
          wrapper.style.minHeight = `${fullHeightPx}px`;
          wrapper.style.width = "100%";
          wrapper.style.display = "flex";
          wrapper.style.alignItems = "center";
          wrapper.style.justifyContent = "center";
        }

        img.classList.add("mermaid-fullpage");
        img.style.width = "100%";
        img.style.height = "100%";
        img.style.objectFit = "contain";
        img.style.margin = "0 auto";

        const parent = img.parentElement;

        if (parent) {
          parent.style.height = "100%";
          parent.style.width = "100%";
          parent.style.margin = "0";
          parent.style.display = "flex";
          parent.style.alignItems = "center";
          parent.style.justifyContent = "center";
        }
      }
    });
  }, { thresholdRatio: fullpageThresholdRatio, printableWidthPx, printableHeightPx });

  const headerTemplate = `<div></div>`;

  const footerTemplate = `
    <div style="font-size:9px; width:100%; padding:0 8mm; display:flex; justify-content:flex-end;">
      <span><span class="pageNumber"></span>/<span class="totalPages"></span></span>
    </div>`;

  await page.pdf({
    path: pdfPath,
    format: "A4",
    printBackground: true,
    displayHeaderFooter: true,
    headerTemplate,
    footerTemplate,
    margin: {
      top: `${marginTopMm}mm`,
      bottom: `${marginBottomMm}mm`,
      left: `${marginLeftMm}mm`,
      right: `${marginRightMm}mm`,
    },
  });

  await browser.close();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
