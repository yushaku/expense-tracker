const { getDefaultConfig } = require('expo/metro-config');

// SDK 52+: Expo auto-configures monorepos. Keep defaults.
const config = getDefaultConfig(__dirname);

module.exports = config;
