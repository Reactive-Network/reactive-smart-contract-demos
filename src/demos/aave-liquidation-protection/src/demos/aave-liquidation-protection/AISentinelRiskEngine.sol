// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

/// @title Institutional AISentinelRiskEngine
/// @notice Explainable deterministic risk engine for Reactive DeFi protection.
/// @dev This is AI-assisted logic, but the on-chain result is deterministic and auditable.
contract AISentinelRiskEngine {
    enum RecommendedAction {
        NO_ACTION,
        ALERT_ONLY,
        ADD_COLLATERAL,
        REPAY_DEBT,
        BOTH,
        EMERGENCY,
        PAUSE_AUTOMATION
    }

    enum RiskRegime {
        SAFE,
        WATCH,
        ELEVATED,
        HIGH,
        CRITICAL
    }

    struct RiskInput {
        uint256 healthFactor;
        uint256 healthFactorThreshold;
        uint256 targetHealthFactor;
        uint256 totalCollateralUSD;
        uint256 totalDebtUSD;

        uint256 volatilityScore;
        uint256 liquidityScore;
        uint256 marketRiskScore;
        uint256 oracleDeviationScore;
        uint256 whaleFlowScore;
        uint256 chainCongestionScore;
        uint256 protocolRiskScore;

        uint256 failedExecutionCount;
        uint256 timeSinceLastExecution;
        bool priceOracleHealthy;
        bool automationPaused;
    }

    struct RiskResult {
        uint256 riskScore;
        RiskRegime regime;
        RecommendedAction action;
        string reason;
    }

    uint256 private constant WAD = 1e18;

    function calculateRisk(RiskInput memory input) public pure returns (RiskResult memory) {
        if (input.automationPaused) {
            return RiskResult(100, RiskRegime.CRITICAL, RecommendedAction.PAUSE_AUTOMATION, "Automation manually paused");
        }

        if (!input.priceOracleHealthy || input.oracleDeviationScore >= 80) {
            return RiskResult(95, RiskRegime.CRITICAL, RecommendedAction.PAUSE_AUTOMATION, "Oracle risk too high");
        }

        uint256 score =
            _healthFactorRisk(input) +
            _debtExposureRisk(input) +
            _marketStructureRisk(input) +
            _executionRisk(input);

        if (score > 100) score = 100;

        return _decision(score, input);
    }

    function _healthFactorRisk(RiskInput memory input) internal pure returns (uint256) {
        if (input.healthFactor <= 103 * WAD / 100) return 45;
        if (input.healthFactor <= 110 * WAD / 100) return 38;
        if (input.healthFactor <= 125 * WAD / 100) return 28;
        if (input.healthFactor < input.healthFactorThreshold) return 20;
        if (input.healthFactor < input.targetHealthFactor) return 10;
        return 0;
    }

    function _debtExposureRisk(RiskInput memory input) internal pure returns (uint256) {
        if (input.totalDebtUSD == 0 || input.totalCollateralUSD == 0) return 0;

        uint256 debtRatio = (input.totalDebtUSD * 100) / input.totalCollateralUSD;

        if (debtRatio >= 90) return 25;
        if (debtRatio >= 80) return 20;
        if (debtRatio >= 65) return 14;
        if (debtRatio >= 50) return 8;
        return 2;
    }

    function _marketStructureRisk(RiskInput memory input) internal pure returns (uint256) {
        uint256 score = 0;

        score += _cap(input.volatilityScore, 15);
        score += _cap(input.liquidityScore, 15);
        score += _cap(input.marketRiskScore, 15);
        score += _cap(input.whaleFlowScore, 10);
        score += _cap(input.protocolRiskScore, 10);

        return score;
    }

    function _executionRisk(RiskInput memory input) internal pure returns (uint256) {
        uint256 score = 0;

        score += _cap(input.chainCongestionScore, 10);

        if (input.failedExecutionCount >= 3) score += 20;
        else if (input.failedExecutionCount == 2) score += 12;
        else if (input.failedExecutionCount == 1) score += 6;

        if (input.timeSinceLastExecution < 5 minutes) score += 5;

        return score;
    }

    function _decision(uint256 score, RiskInput memory input) internal pure returns (RiskResult memory) {
        if (input.failedExecutionCount >= 5) {
            return RiskResult(score, RiskRegime.CRITICAL, RecommendedAction.PAUSE_AUTOMATION, "Too many failed executions");
        }

        if (score >= 90) {
            return RiskResult(score, RiskRegime.CRITICAL, RecommendedAction.EMERGENCY, "Critical liquidation and market risk");
        }

        if (score >= 76) {
            return RiskResult(score, RiskRegime.HIGH, RecommendedAction.BOTH, "High risk: repay debt and add collateral");
        }

        if (score >= 61) {
            if (input.liquidityScore >= input.volatilityScore) {
                return RiskResult(score, RiskRegime.HIGH, RecommendedAction.REPAY_DEBT, "High liquidity risk: reduce debt first");
            }

            return RiskResult(score, RiskRegime.ELEVATED, RecommendedAction.ADD_COLLATERAL, "High volatility risk: add collateral first");
        }

        if (score >= 46) {
            return RiskResult(score, RiskRegime.ELEVATED, RecommendedAction.ALERT_ONLY, "Elevated risk: alert and monitor");
        }

        if (score >= 26) {
            return RiskResult(score, RiskRegime.WATCH, RecommendedAction.ALERT_ONLY, "Watchlist risk");
        }

        return RiskResult(score, RiskRegime.SAFE, RecommendedAction.NO_ACTION, "Position appears safe");
    }

    function _cap(uint256 value, uint256 maxValue) internal pure returns (uint256) {
        return value > maxValue ? maxValue : value;
    }
}