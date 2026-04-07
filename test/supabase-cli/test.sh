#!/bin/bash
set -e
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "supabase CLI is installed" command -v supabase
check "supabase CLI is executable" test -x "$(command -v supabase)"
check "supabase-post-start helper is installed" test -f /usr/local/bin/supabase-post-start
check "supabase-post-start helper is executable" test -x /usr/local/bin/supabase-post-start
check "supabase --version runs" supabase --version

reportResults
