import Stats from 'stats.js';
import { GUI } from 'dat.gui';

import { initWebGPU, Renderer } from './renderer';
import { NaiveRenderer } from './renderers/naive';
import { ForwardPlusRenderer } from './renderers/forward_plus';
import { ClusteredDeferredRenderer } from './renderers/clustered_deferred';

import { setupLoaders, Scene } from './stage/scene';
import { Lights } from './stage/lights';
import { Camera } from './stage/camera';
import { Stage } from './stage/stage';
import { BenchmarkRunner } from './testing/benchmark';

await initWebGPU();
setupLoaders();

let scene = new Scene();
await scene.loadGltf('./scenes/sponza/Sponza.gltf');

const camera = new Camera();
const lights = new Lights(camera);

const stats = new Stats();
stats.showPanel(0);
document.body.appendChild(stats.dom);

const gui = new GUI();
gui.add(lights, 'numLights').min(1).max(Lights.maxNumLights).step(1).onChange(() => {
    lights.updateLightSetUniformNumLights();
});

const stage = new Stage(scene, lights, camera, stats);

var renderer: Renderer | undefined;

function setRenderer(mode: string): Renderer | undefined {
    renderer?.stop();

    switch (mode) {
        case renderModes.naive:
            renderer = new NaiveRenderer(stage);
            break;
        case renderModes.forwardPlus:
            renderer = new ForwardPlusRenderer(stage);
            break;
        case renderModes.clusteredDeferred:
            renderer = new ClusteredDeferredRenderer(stage);
            break;
    }

    return renderer;
}

const renderModes = { naive: 'naive', forwardPlus: 'forward+', clusteredDeferred: 'clustered deferred' };
let renderModeController = gui.add({ mode: renderModes.clusteredDeferred }, 'mode', renderModes);
renderModeController.onChange(setRenderer);

setRenderer(renderModeController.getValue());

// Setup benchmark runner
const benchmarkRunner = new BenchmarkRunner(
    stage,
    setRenderer
);

// Add progress display element
const progressDiv = document.createElement('div');
progressDiv.id = 'benchmark-progress';
progressDiv.style.position = 'fixed';
progressDiv.style.top = '50%';
progressDiv.style.left = '50%';
progressDiv.style.transform = 'translate(-50%, -50%)';
progressDiv.style.backgroundColor = 'rgba(0, 0, 0, 0.8)';
progressDiv.style.color = 'white';
progressDiv.style.padding = '20px';
progressDiv.style.borderRadius = '10px';
progressDiv.style.fontFamily = 'monospace';
progressDiv.style.fontSize = '14px';
progressDiv.style.display = 'none';
progressDiv.style.zIndex = '1000';
progressDiv.style.maxWidth = '600px';
progressDiv.style.maxHeight = '400px';
progressDiv.style.overflow = 'auto';
document.body.appendChild(progressDiv);

// Setup benchmark callbacks
benchmarkRunner.setProgressCallback((message: string) => {
    progressDiv.style.display = 'block';
    progressDiv.innerHTML += message + '<br>';
    progressDiv.scrollTop = progressDiv.scrollHeight;
});

benchmarkRunner.setCompleteCallback((results) => {
    progressDiv.innerHTML += '<br><strong>Benchmark complete! Downloading CSV...</strong><br>';
    setTimeout(() => {
        benchmarkRunner.downloadCSV(`benchmark_results_${Date.now()}.csv`);
        setTimeout(() => {
            progressDiv.style.display = 'none';
            progressDiv.innerHTML = '';
            // Restore the original renderer
            setRenderer(renderModeController.getValue());
        }, 2000);
    }, 1000);
});

// Add benchmark button to GUI
const benchmarkControls = {
    startBenchmark: () => {
        if (benchmarkRunner.isTestRunning()) {
            alert('Benchmark is already running!');
            return;
        }
        if (confirm('This will run automated performance tests for all rendering modes with different light counts. This may take several minutes. Continue?')) {
            progressDiv.innerHTML = '<strong>Starting benchmark...</strong><br>';
            progressDiv.style.display = 'block';
            // Start benchmark after a short delay to let UI update
            setTimeout(() => {
                benchmarkRunner.runBenchmark();
            }, 100);
        }
    }
};

gui.add(benchmarkControls, 'startBenchmark').name('Start Testing');
