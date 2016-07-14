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
  core/cacerts
  core/coreutils
  core/git
)
pkg_bin_dirs=(bin)
pkg_svc_run="bin/dcob"

do_download() {
  return 0
}

do_verify() {
  return 0
}

do_unpack() {
  return 0
}

do_prepare() {
  # Create a Gemfile with what we need
  cat > Gemfile <<GEMFILE
source 'https://rubygems.org'
gem 'dcob', path: '$pkg_prefix'
GEMFILE
}

do_build() {
  export BUNDLE_SILENCE_ROOT_WARNING=1 GEM_PATH
  GEM_PATH="$(pkg_path_for core/bundler)"
  cp -a "$PLAN_CONTEXT/.." "$pkg_prefix"
  bundle install --jobs "$(nproc)" --retry 5 --standalone \
    --path "$pkg_prefix/bundle" \
    --binstubs "$pkg_prefix/bin"
}

do_install () {
  fix_interpreter "$pkg_prefix/bin/*" core/coreutils bin/env
}
