/**
 * Boot: safe-area → device preview → design stage → DOM app.
 *
 * The cycling UI is flat DOM inside #ui-root, so no WebGPU renderer is
 * created here (create-renderer.ts is kept for when 3D is needed).
 * Keep: adapt/*, utils/haptics, DOM contract.
 */

import '@fontsource/barlow-condensed/500.css';
import '@fontsource/barlow-condensed/600.css';
import '@fontsource/barlow-condensed/700.css';

import { Capacitor } from '@capacitor/core';
import {
  applyStageTransform,
  computeStageLayout,
  watchStageLayout,
  type StageLayout,
} from './adapt/design';
import { mountDevicePreview, type DevicePreviewController } from './adapt/devicePreview';
import { applyNativeClass, applySafeAreaCssVars } from './adapt/safeArea';
import { mountApp } from './ui/app';
import { haptics } from './utils/haptics';

const shell = document.getElementById('shell')!;
const viewportEl = document.getElementById('viewport')!;
const stage = document.getElementById('stage')!;
const uiRoot = document.getElementById('ui-root')!;

function boot(): void {
  applyNativeClass();
  const native = Capacitor.isNativePlatform();

  let preview: DevicePreviewController;

  const onLayout = (layout: StageLayout) => {
    applyStageTransform(stage, layout);
    applySafeAreaCssVars(native);
    if (new URLSearchParams(window.location.search).has('debugFit')) {
      console.info('[debugFit]', layout, preview?.getDevice());
    }
  };

  preview = mountDevicePreview(shell, viewportEl, () => {
    const size = preview.getViewSize();
    onLayout(computeStageLayout(size.width, size.height, 'contain'));
  });

  const unwatch = watchStageLayout(onLayout, {
    mode: 'contain',
    getViewSize: () => preview.getViewSize(),
  });

  void mountApp(uiRoot, stage);

  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && haptics.isNativeIos()) void haptics.prepare();
  });

  window.addEventListener(
    'pagehide',
    () => {
      unwatch();
      preview.dispose();
    },
    { once: true },
  );
}

boot();
