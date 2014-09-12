#!/usr/bin/env bash

git_dir="gh-pages"

rake

git clone --branch gh-pages https://github.com/Keithbsmiley/smileykeith.com.git $git_dir
rm -rf $git_dir/*
mv _site/* _site/.* $git_dir
cd $git_dir; git add --all; git commit -m "`date`"; true
cd $git_dir; git push
rm -rf $git_dir
