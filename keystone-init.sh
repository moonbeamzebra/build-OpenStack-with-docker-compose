#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo "Running Keystone-init setup..."

if [[ -f /init.done ]]; then
    echo "Setup already completed."
    exit 0
fi

########################################
# Helpers
########################################

########################################
# retry compatible set -e
########################################
retry() {
    local retries="$1"
    shift

    local no_retry_codes=()

    while [[ "$1" != "--" ]]; do
        no_retry_codes+=("$1")
        shift
    done
    shift

    [[ ${#no_retry_codes[@]} -eq 0 ]] && no_retry_codes=(0)

    local count=0
    local rc

    while true; do
        set +e
        "$@"
        rc=$?
        for code in "${no_retry_codes[@]}"; do
            [[ $rc -eq $code ]] && set -e && return $rc
        done

        ((count++))
        if ((count >= retries)); then
            echo "Command failed after $count attempts (rc=$rc)"
            return "$rc"
        fi

        echo "====="
        echo "RETRY: [$@] $count/$retries (rc=$rc) ... in 3 seconds"
        echo "====="
        sleep 3
    done
}

echo "Waiting for Keystone API..."

until curl -sf http://keystone:5000/v3 >/dev/null; do
  sleep 2
done

export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://keystone:5000/v3
export OS_IDENTITY_API_VERSION=3

echo "DO openstack domain create --description "An Example Domain" example"
retry 10 0 1 -- openstack domain show example >/dev/null 2>&1 || \
retry 10 0 -- openstack domain create --description "An Example Domain" example
echo "DONE RC=$? ;openstack domain create --description "An Example Domain" example"

echo "DO openstack project create --domain default --description "Service Project" service"
retry 10 0 1 -- openstack project show --domain default service >/dev/null 2>&1 || \
retry 10 0 -- openstack project create --domain default --description "Service Project" service
echo "DONE RC=$? ;openstack project create --domain default --description "Service Project" service"

echo "DO openstack project create --domain default --description "Demo Project" user-project"
retry 10 0 1 -- openstack project show --domain default user-project >/dev/null 2>&1 || \
retry 10 0 -- openstack project create --domain default --description "Demo Project" user-project
echo "DONE RC=$? ;openstack project create --domain default --description "Demo Project" user-project"

echo "DONE openstack user create --domain default --password $DEMO_PASS user-demo"
retry 10 0 1 -- openstack user show --domain default user-demo >/dev/null 2>&1 || \
retry 10 0 -- openstack user create --domain default --password $DEMO_PASS user-demo
echo "DONE RC=$? ;openstack user create --domain default --password $DEMO_PASS user-demo"

echo "DO openstack role create user-role"
retry 10 0 1 -- openstack role show user-role >/dev/null 2>&1 || \
retry 10 0 -- openstack role create user-role
echo "DONE RC=$? ;openstack role create user-role"

echo "DO openstack role add --project user-project --user user-demo user-role"
retry 10 0 1 -- openstack role assignment list --user user-demo --project user-project -f value --names | grep -q user-role || \
retry 10 0 -- openstack role add --project user-project --user user-demo user-role
echo "DONE RC=$? ;openstack role add --project user-project --user user-demo user-role"

echo "Keystone Keystone-init.sh completed successfully."

touch /init.done

