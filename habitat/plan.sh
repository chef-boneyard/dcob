pkg_name=dcob
pkg_origin=chef_community_engineering
pkg_version=_computed_in_a_function_below_
pkg_description="This is a github bot to ensure every commit on a PR has the
  Signed-off-by attribution required by the Developer Certificate of Origin."
pkg_upstream_url=https://github.com/habitat-sh/dcob
pkg_maintainer="Chef Community Engineering Team <community@chef.io>"
pkg_license=('MIT')
pkg_source=false
pkg_deps=(
  core/cacerts
  core/coreutils
  core/ruby
)
pkg_build_deps=(
  core/bundler
  core/git
)
pkg_bin_dirs=(bin)
pkg_svc_run="dcob -o 0.0.0.0"
pkg_expose=(4567)

determine_version() {
  # Ask the DCOB gem what version it is. Use that as the hab package version.
  # Only have to set/bump version in one place like we would for any gem.
  pkg_version=$(ruby -I$PLAN_CONTEXT/../src/lib/dcob -rversion -e 'puts Dcob::VERSION')
  pkg_dirname=${pkg_name}-${pkg_version}
  pkg_filename=${pkg_dirname}.tar.gz
  pkg_prefix=$HAB_PKG_PATH/${pkg_origin}/${pkg_name}/${pkg_version}/${pkg_release}
  pkg_artifact="$HAB_CACHE_ARTIFACT_PATH/${pkg_origin}-${pkg_name}-${pkg_version}-${pkg_release}-${pkg_target}.${_artifact_ext}"
}

do_download() {
  determine_version

  # Instead of downloading, build a gem based on the source in src/
  cd $PLAN_CONTEXT/../src
  gem build $pkg_name.gemspec
}

do_verify() {
  # No download to verify.
  return 0
}

do_unpack() {
  # Unpack the gem we built to the source cache path. Building then unpacking
  # the gem reuses the file inclusion/exclusion rules defined in the gemspec.
  gem unpack $PLAN_CONTEXT/../src/$pkg_name-$pkg_version.gem --target=$HAB_CACHE_SRC_PATH
}

do_build() {
  export GIT_DIR=$PLAN_CONTEXT/../.git # appease the git command in the gemspec
  export BUNDLE_SILENCE_ROOT_WARNING=1 GEM_PATH
  GEM_PATH="$(pkg_path_for core/bundler)"

  bundle install --jobs "$(nproc)" --retry 5 --standalone \
    --without development \
    --path "bundle" \
    --binstubs
}

do_install () {
  fix_interpreter "bin/*" core/coreutils bin/env
  cp -a "." "$pkg_prefix"
}
