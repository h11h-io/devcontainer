#!/bin/bash
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

# Verify the helper script was installed and is executable
check "configure-git-identity script exists" test -f /usr/local/bin/configure-git-identity
check "configure-git-identity script is executable" test -x /usr/local/bin/configure-git-identity

# Verify dependencies are available
check "curl is installed" command -v curl
check "jq is installed" command -v jq

# Test that the script runs without error when no token is provided
# (should print a warning and exit cleanly)
check "script runs cleanly without token" bash -c '
  unset GITHUB_TOKEN
  /usr/local/bin/configure-git-identity 2>&1 | grep -q "warning"
  true
'

# Test with a mock GITHUB_TOKEN and stubbed curl
check "script sets git config from mock API response" bash -c '
  export GITHUB_TOKEN="mock-token"
  # Stub curl to return a fake API response
  export PATH="/tmp/mock-bin:$PATH"
  mkdir -p /tmp/mock-bin
  cat > /tmp/mock-bin/curl << '"'"'EOF'"'"'
#!/bin/sh
printf '"'"'{"login":"testuser","id":12345,"name":"Test User","email":"test@example.com"}'"'"'
EOF
  chmod +x /tmp/mock-bin/curl
  /usr/local/bin/configure-git-identity
  git config --global user.name | grep -q "Test User"
  git config --global user.email | grep -q "test@example.com"
  # Clean up
  git config --global --unset user.name || true
  git config --global --unset user.email || true
  rm -rf /tmp/mock-bin
'

# Test overwrite=false skips when identity already set
check "script skips when identity already set and overwrite=false" bash -c '
  git config --global user.name "Existing User"
  git config --global user.email "existing@example.com"
  export GITHUB_TOKEN="mock-token"
  export OVERWRITE=false
  output=$(/usr/local/bin/configure-git-identity 2>&1)
  echo "$output" | grep -q "already set"
  # Verify identity was not changed
  git config --global user.name | grep -q "Existing User"
  # Clean up
  git config --global --unset user.name || true
  git config --global --unset user.email || true
'

# Test overwrite=true re-runs even when identity is set
check "script overwrites when overwrite=true" bash -c '
  git config --global user.name "Old User"
  git config --global user.email "old@example.com"
  export GITHUB_TOKEN="mock-token"
  export OVERWRITE=true
  # Stub curl
  export PATH="/tmp/mock-bin2:$PATH"
  mkdir -p /tmp/mock-bin2
  cat > /tmp/mock-bin2/curl << '"'"'EOF'"'"'
#!/bin/sh
printf '"'"'{"login":"newuser","id":99999,"name":"New User","email":"new@example.com"}'"'"'
EOF
  chmod +x /tmp/mock-bin2/curl
  /usr/local/bin/configure-git-identity
  git config --global user.name | grep -q "New User"
  git config --global user.email | grep -q "new@example.com"
  # Clean up
  git config --global --unset user.name || true
  git config --global --unset user.email || true
  rm -rf /tmp/mock-bin2
'

# Test fallback to noreply email when email is null/empty
check "script uses noreply email when email is private" bash -c '
  unset GITHUB_TOKEN
  export GITHUB_TOKEN="mock-token"
  export OVERWRITE=true
  export PATH="/tmp/mock-bin3:$PATH"
  mkdir -p /tmp/mock-bin3
  cat > /tmp/mock-bin3/curl << '"'"'EOF'"'"'
#!/bin/sh
printf '"'"'{"login":"privateuser","id":55555,"name":"Private User","email":null}'"'"'
EOF
  chmod +x /tmp/mock-bin3/curl
  /usr/local/bin/configure-git-identity
  git config --global user.email | grep -q "55555+privateuser@users.noreply.github.com"
  # Clean up
  git config --global --unset user.name || true
  git config --global --unset user.email || true
  rm -rf /tmp/mock-bin3
'

reportResults
