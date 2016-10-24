pkg_name=dcob
pkg_origin=core
pkg_version=0.1.0
pkg_description="This is a github bot to ensure every commit on a PR has the
  Signed-off-by attribution required by the Developer Certificate of Origin."
pkg_upstream_url=https://github.com/habitat-sh/dcob
pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"
pkg_license=('MIT')
pkg_source=false
pkg_deps=(
  core/coreutils
  core/ruby
)
pkg_build_deps=(
  core/bundler
  core/git
)
pkg_bin_dirs=(bin)
pkg_expose=(4567)

do_download() {
  return 0
}

do_verify() {
  return 0
}

do_unpack() {
  return 0
}

do_build() {
  cd $PLAN_CONTEXT/../src
  # Build then unpack the gem to the source cache path to limit the
  # files packaged to those defined as included in the gemspec
  gem build $pkg_name.gemspec
  gem unpack $pkg_name-$pkg_version.gem --target=$HAB_CACHE_SRC_PATH
}

do_install () {
  export GIT_DIR=$PLAN_CONTEXT/../.git # appease the git command in the gemspec
  export BUNDLE_SILENCE_ROOT_WARNING=1 GEM_PATH
  GEM_PATH="$(pkg_path_for core/bundler)"

  bundle install --jobs "$(nproc)" --retry 5 --standalone \
    --path "bundle" \
    --binstubs

  fix_interpreter "bin/*" core/coreutils bin/env
  cp -a "." "$pkg_prefix"
}
