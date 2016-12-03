pkg_name=dcob
pkg_origin=core
pkg_version=_computed_
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
  pkg_version=$(ruby -I$PLAN_CONTEXT/../src/lib/dcob -rversion -e 'puts Dcob::VERSION')
  pkg_dirname=${pkg_name}-${pkg_version}
  pkg_filename=${pkg_dirname}.tar.gz
  pkg_prefix=$HAB_PKG_PATH/${pkg_origin}/${pkg_name}/${pkg_version}/${pkg_release}
  pkg_artifact="$HAB_CACHE_ARTIFACT_PATH/${pkg_origin}-${pkg_name}-${pkg_version}-${pkg_release}-${pkg_target}.${_artifact_ext}"
}

do_download() {
  determine_version
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
    --without development \
    --path "bundle" \
    --binstubs

  fix_interpreter "bin/*" core/coreutils bin/env
  cp -a "." "$pkg_prefix"
}
