import { Stage } from '../stage/stage';
import { Renderer, setFrameTimeCallback } from '../renderer';

export interface BenchmarkResult {
    renderMode: string;
    numLights: number;
    avgFrameTimeMs: number;
    minFrameTimeMs: number;
    maxFrameTimeMs: number;
}

export class BenchmarkRunner {
    private stage: Stage;
    private rendererFactory: (mode: string) => Renderer | undefined;
    private results: BenchmarkResult[] = [];
    private isRunning = false;
    private onProgressCallback?: (message: string) => void;
    private onCompleteCallback?: (results: BenchmarkResult[]) => void;

    // For frame time measurement
    private frameTimes: number[] = [];
    private isCollecting = false;

    constructor(
        stage: Stage,
        rendererFactory: (mode: string) => Renderer | undefined
    ) {
        this.stage = stage;
        this.rendererFactory = rendererFactory;
    }

    setProgressCallback(callback: (message: string) => void) {
        this.onProgressCallback = callback;
    }

    setCompleteCallback(callback: (results: BenchmarkResult[]) => void) {
        this.onCompleteCallback = callback;
    }

    async runBenchmark() {
        if (this.isRunning) {
            console.warn('Benchmark already running');
            return;
        }

        this.isRunning = true;
        this.results = [];

        // Register frame time callback
        setFrameTimeCallback((frameTime: number) => {
            this.captureFrameTime(frameTime);
        });

        const renderModes = ['naive', 'forward+', 'clustered deferred'];
        const lightCounts = [500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000];

        // Save original state
        const originalNumLights = this.stage.lights.numLights;

        try {
            for (const mode of renderModes) {
                this.log(`Testing ${mode} renderer...`);

                this.rendererFactory(mode);

                await this.delay(200);

                for (const numLights of lightCounts) {
                    this.log(`  Testing with ${numLights} lights...`);

                    this.stage.lights.numLights = numLights;
                    this.stage.lights.updateLightSetUniformNumLights();

                    const result = await this.benchmarkConfiguration(mode, numLights);
                    this.results.push(result);

                    this.log(`    Avg: ${result.avgFrameTimeMs.toFixed(2)}ms, Min: ${result.minFrameTimeMs.toFixed(2)}ms, Max: ${result.maxFrameTimeMs.toFixed(2)}ms`);
                }
            }

            this.log('Benchmark complete! Generating CSV...');

            if (this.onCompleteCallback) {
                this.onCompleteCallback(this.results);
            }

        } finally {
            // Unregister frame time callback
            setFrameTimeCallback(null);

            // Restore original state
            this.stage.lights.numLights = originalNumLights;
            this.stage.lights.updateLightSetUniformNumLights();
            this.isRunning = false;
        }
    }

    private delay(ms: number): Promise<void> {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    private async benchmarkConfiguration(renderMode: string, numLights: number): Promise<BenchmarkResult> {
        await this.waitFrames(30);

        this.frameTimes = [];
        this.isCollecting = true;

        const numSampleFrames = 120;
        await this.collectFrameTimes(numSampleFrames);

        this.isCollecting = false;

        const avgFrameTime = this.frameTimes.reduce((a, b) => a + b, 0) / this.frameTimes.length;
        const minFrameTime = Math.min(...this.frameTimes);
        const maxFrameTime = Math.max(...this.frameTimes);

        return {
            renderMode,
            numLights,
            avgFrameTimeMs: avgFrameTime,
            minFrameTimeMs: minFrameTime,
            maxFrameTimeMs: maxFrameTime
        };
    }

    private collectFrameTimes(numFrames: number): Promise<void> {
        return new Promise<void>((resolve) => {
            let framesCollected = 0;

            const collectFrame = () => {
                if (this.frameTimes.length >= numFrames) {
                    resolve();
                } else {
                    requestAnimationFrame(collectFrame);
                }
            };

            requestAnimationFrame(collectFrame);
        });
    }

    captureFrameTime(frameTimeMs: number) {
        if (this.isCollecting) {
            this.frameTimes.push(frameTimeMs);
        }
    }

    private waitFrames(numFrames: number): Promise<void> {
        return new Promise<void>((resolve) => {
            let framesWaited = 0;

            const waitFrame = () => {
                framesWaited++;
                if (framesWaited >= numFrames) {
                    resolve();
                } else {
                    requestAnimationFrame(waitFrame);
                }
            };

            requestAnimationFrame(waitFrame);
        });
    }

    private log(message: string) {
        console.log(message);
        if (this.onProgressCallback) {
            this.onProgressCallback(message);
        }
    }

    generateCSV(): string {
        if (this.results.length === 0) {
            return 'No results available';
        }

        // CSV header
        let csv = 'Render Mode,Number of Lights,Average Frame Time (ms),Min Frame Time (ms),Max Frame Time (ms)\n';

        // CSV rows
        for (const result of this.results) {
            csv += `${result.renderMode},${result.numLights},${result.avgFrameTimeMs.toFixed(3)},${result.minFrameTimeMs.toFixed(3)},${result.maxFrameTimeMs.toFixed(3)}\n`;
        }

        return csv;
    }

    downloadCSV(filename: string = 'benchmark_results.csv') {
        const csv = this.generateCSV();
        const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        const url = URL.createObjectURL(blob);

        link.setAttribute('href', url);
        link.setAttribute('download', filename);
        link.style.visibility = 'hidden';

        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);

        URL.revokeObjectURL(url);
    }

    isTestRunning(): boolean {
        return this.isRunning;
    }
}
