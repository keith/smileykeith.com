#!/bin/bash

set -euo pipefail

git_dir="gh-pages"

bundle check || bundle install
# For development: bundle exec jekyll server --watch
bundle exec jekyll build

git clone --branch gh-pages https://github.com/keith/smileykeith.com.git $git_dir || true
rm -rf $git_dir/*
mv _site/* $git_dir
cd $git_dir; git add --all; git commit -m "$(date)"; true
# cd $git_dir; git push
# rm -rf $git_dir
