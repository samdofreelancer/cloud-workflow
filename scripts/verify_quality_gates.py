#!/usr/bin/env python3
"""
Quality Gate Verification Script

This script verifies that all quality checks have passed:
- Unit tests execution
- Integration tests execution
- SonarQube quality gates (if enabled)

Exit codes:
  0 = All quality gates passed
  1 = One or more quality gates failed
"""

import os
import sys

def get_env(key, default="unknown"):
    """Get environment variable safely."""
    return os.getenv(key, default)

def parse_job_result(result):
    """Parse GitHub Actions job result."""
    result = result.lower().strip()
    return result in ["success", "skipped"]

def main():
    """Main verification logic."""
    unit_test_result = get_env("UNIT_TEST_RESULT", "unknown")
    integration_test_result = get_env("INTEGRATION_TEST_RESULT", "unknown")
    sonar_result = get_env("SONAR_RESULT", "unknown")
    sonar_status = get_env("SONAR_STATUS", "not-run")

    print("=" * 60)
    print("Quality Gate Verification")
    print("=" * 60)

    # Check unit tests
    unit_passed = parse_job_result(unit_test_result)
    status_icon = "✅" if unit_passed else "❌"
    print(f"{status_icon} Unit Tests: {unit_test_result}")

    # Check integration tests
    int_passed = parse_job_result(integration_test_result)
    status_icon = "✅" if int_passed else "❌"
    print(f"{status_icon} Integration Tests: {integration_test_result}")

    # Check SonarQube (can be skipped)
    sonar_passed = parse_job_result(sonar_result)
    status_icon = "✅" if sonar_passed else "⚠️" if sonar_result == "skipped" else "❌"
    print(f"{status_icon} SonarQube Scan: {sonar_result}")
    if sonar_status != "not-run":
        print(f"   Quality Gate Status: {sonar_status}")

    print("=" * 60)

    # Overall result
    all_passed = unit_passed and int_passed and sonar_passed
    
    if all_passed:
        print("✅ All quality gates PASSED")
        print("=" * 60)
        return 0
    else:
        print("❌ Some quality gates FAILED")
        print("=" * 60)
        return 1

if __name__ == "__main__":
    sys.exit(main())
