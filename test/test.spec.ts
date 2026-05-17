declare const __dirname: string;
declare const process: { env: { SHELL?: string } };
declare const require: (moduleName: string) => any;
declare const describe: any;
declare const expect: any;
declare const test: any;

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const repoRoot = path.resolve(__dirname, '..');
const fixturesDir = path.join(repoRoot, 'fixtures');
const expectedOutputsDir = path.join(repoRoot, 'grader', 'expected_outputs');
const outDir = path.join(repoRoot, 'out');

function compareStrings(left: string, right: string): number {
	if (left < right) {
		return -1;
	}

	if (left > right) {
		return 1;
	}

	return 0;
}

function compareKeys(left: { primary: string; secondary: string }, right: { primary: string; secondary: string }): number {
	const primaryComparison = compareStrings(left.primary, right.primary);
	if (primaryComparison !== 0) {
		return primaryComparison;
	}

	return compareStrings(left.secondary, right.secondary);
}

function readJson(filePath: string): unknown {
	return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function readExecErrorText(value: unknown, fieldName: 'stdout' | 'stderr'): string {
	if (typeof value !== 'object' || value === null) {
		return '';
	}

	const candidate = (value as { [key: string]: unknown })[fieldName];
	if (typeof candidate === 'string') {
		return candidate;
	}

	if (candidate === undefined || candidate === null) {
		return '';
	}

	return String(candidate);
}

function assertSortedRejectedVotes(value: unknown): void {
	if (value === undefined || value === null) {
		return;
	}

	expect(Array.isArray(value)).toBe(true);

	const entries = value as Array<Record<string, unknown>>;
	if (entries.length <= 1) {
		return;
	}

	const keys = entries.map((entry, index) => {
		const address = entry.address;
		const code = entry.code;

		if (typeof address === 'string' && address.length > 0) {
			return {
				primary: address,
				secondary: typeof code === 'string' && code.length > 0 ? code : '',
			};
		}

		if (typeof code === 'string' && code.length > 0) {
			return {
				primary: code,
				secondary: typeof address === 'string' && address.length > 0 ? address : '',
			};
		}

		throw new Error(`rejected_votes[${index}] must include an address or a code`);
	});

	const sortedKeys = [...keys].sort(compareKeys);
	expect(keys).toEqual(sortedKeys);
}

function assertSortedWarnings(value: unknown): void {
	if (value === undefined || value === null) {
		return;
	}

	expect(Array.isArray(value)).toBe(true);

	const entries = value as Array<Record<string, unknown>>;
	if (entries.length <= 1) {
		return;
	}

	const keys = entries.map((entry, index) => {
		const code = entry.code;
		if (typeof code !== 'string' || code.length === 0) {
			throw new Error(`warnings[${index}] must include a code`);
		}

		return code;
	});

	const sortedKeys = [...keys].sort(compareStrings);
	expect(keys).toEqual(sortedKeys);
}

function runFixtureTest(fixtureFileName: string): void {
	const fixtureName = path.basename(fixtureFileName, '.json');
	const inputFixturePath = path.join(fixturesDir, fixtureFileName);
	const actualOutputPath = path.join(outDir, `${fixtureName}.json`);
	const expectedOutputPath = path.join(expectedOutputsDir, `${fixtureName}.json`);

	expect(fs.existsSync(inputFixturePath)).toBe(true);
	expect(fs.existsSync(expectedOutputPath)).toBe(true);

	fs.rmSync(actualOutputPath, { force: true, recursive: true });

	try {
		execSync(`./cli.sh fixtures/${fixtureFileName}`, {
			cwd: repoRoot,
			encoding: 'utf8',
			stdio: ['ignore', 'pipe', 'pipe'],
			shell: process.env.SHELL || 'bash',
		});
	} catch (error: unknown) {
		const stderrText = readExecErrorText(error, 'stderr');
		const stdoutText = readExecErrorText(error, 'stdout');

		if (stdoutText.length > 0) {
			console.error(stdoutText);
		}

		if (stderrText.length > 0) {
			console.error(stderrText);
		}

		const status = typeof error === 'object' && error !== null && typeof (error as { status?: unknown }).status === 'number'
			? (error as { status: number }).status
			: 'unknown';

		throw new Error(`cli.sh failed for ${fixtureFileName} with exit code ${status}`);
	}

	expect(fs.existsSync(actualOutputPath)).toBe(true);

	const actualOutput = readJson(actualOutputPath);
	const expectedOutput = readJson(expectedOutputPath);

	expect(typeof actualOutput).toBe('object');
	expect(actualOutput).not.toBeNull();

	const actualObject = actualOutput as Record<string, unknown>;
	if (actualObject.rejected_votes !== undefined && actualObject.rejected_votes !== null) {
		assertSortedRejectedVotes(actualObject.rejected_votes);
	}

	if (actualObject.warnings !== undefined && actualObject.warnings !== null) {
		assertSortedWarnings(actualObject.warnings);
	}

	expect(actualOutput).toEqual(expectedOutput);
}

if (!fs.existsSync(fixturesDir)) {
	throw new Error(`Missing fixtures directory: ${fixturesDir}`);
}

if (!fs.existsSync(expectedOutputsDir)) {
	throw new Error(`Missing expected outputs directory: ${expectedOutputsDir}`);
}

const fixtureFileNames = fs
	.readdirSync(fixturesDir)
	.filter((entry: string) => entry.endsWith('.json'))
	.sort(compareStrings);

if (fixtureFileNames.length === 0) {
		throw new Error(`No JSON fixtures found in ${fixturesDir}`);
}

describe('secretary grader', () => {
	for (const fixtureFileName of fixtureFileNames) {
		test(`matches expected output for ${fixtureFileName}`, () => {
			runFixtureTest(fixtureFileName);
		});
	}
});
