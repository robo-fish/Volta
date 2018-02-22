#!/bin/sh
pushd ..

xcodebuild -workspace Volta.xcworkspace -scheme Volta archive

popd
