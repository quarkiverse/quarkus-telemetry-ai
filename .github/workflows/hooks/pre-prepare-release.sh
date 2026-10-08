#!/bin/bash
# Exclude companion modules (proxy, app, ext) during release:prepare
echo "MAVEN_OPTS=${MAVEN_OPTS} -DskipCompanion" >> "$GITHUB_ENV"
