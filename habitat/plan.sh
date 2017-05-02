pkg_name=dcob
pkg_origin=chef_community_engineering
pkg_description="This is a github bot to ensure every commit on a PR has the
  Signed-off-by attribution required by the Developer Certificate of Origin."
pkg_upstream_url=https://github.com/habitat-sh/dcob
pkg_maintainer="Chef Community Engineering Team <community@chef.io>"
pkg_license=('MIT')
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

pkg_version() {
  # Ask the DCOB gem what version it is. Use that as the hab package version.
  # Only have to set/bump version in one place like we would for any gem.
  ruby -I"$SRC_PATH/src/lib/dcob" -rversion -e 'puts Dcob::VERSION'
}

de_before() {
  do_default_before
  update_pkg_version
}

do_download() {
  # Instead of downloading, build a gem based on the source in src/
  cd "$SRC_PATH/src"
  gem build $pkg_name.gemspec
}

do_unpack() {
  # Unpack the gem we built to the source cache path. Building then unpacking
  # the gem reuses the file inclusion/exclusion rules defined in the gemspec.
  gem unpack $PLAN_CONTEXT/../src/$pkg_name-$pkg_version.gem --target=$HAB_CACHE_SRC_PATH
}

do_build() {
  export GIT_DIR=$SRC_PATH/.git # appease the git command in the gemspec
  GEM_PATH="$(pkg_path_for core/bundler)"
  export BUNDLE_SILENCE_ROOT_WARNING=1 GEM_PATH
  cd "$CACHE_PATH"

  bundle install --jobs "$(nproc)" --retry 5 --standalone \
    --without development \
    --path "bundle" \
    --binstubs
}

do_install () {
  cd "$CACHE_PATH"
  fix_interpreter "bin/*" core/coreutils bin/env
  cp -a "." "$pkg_prefix"
}
