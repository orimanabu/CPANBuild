#!/bin/sh

find . -maxdepth 1 -type d | grep -v '^\.$' | xargs rm -r
