/**
 * Single source of truth for Brownie C's verified support snapshot and shared public CLI caps.
 * Validated across all locale status-and-limits pages by scripts/check-navigation.mjs.
 */
export const supportStatus = {
	baseline: {
		date: '2026-11-16',
		commit: 'f5e13f9',
	},
	limits: {
		sourceFileCount: '1',
		sourceMaxBytes: '4096',
		sourceMaxTokens: '1024',
		maxFunctions: '16',
		globalRegisters: '128',
		vmInstructions: '256',
		maxCallFrames: '32',
		aggregateSites: '16',
		maxArrayElements: '4096',
		arenaKiB: '64',
		defaultFuel: '256',
		maxFuel: '16000000',
	},
	requiredTokens: ['"core": true', 'restricted: false', 'embed: false'],
};
