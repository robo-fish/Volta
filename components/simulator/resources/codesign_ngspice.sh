#!/bin/sh
# codesign -s <full name or 40-digit SHA1 hash of the app developer certificate> --entitlements <path to the app entitlements file> <path to binary to be signed>
codesign -s "3rd Party Mac Developer Application: ? ?" --entitlements ../NGSpice.entitlements ngspice
