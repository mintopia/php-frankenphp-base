# Base FrankenPHP Image for Mintopia's Projects

## Introduction

This is a base PHP image designed for use in my own projects:

 - [Control](https://github.com/mintopia/control)
 - [Music Party](https://github.com/mintopia/musicparty)

It exists because some of the extensions I require take a LONG time to build.

## Supported Versions

This is built from the latest FrankenPHP images and will track the latest versions of them where possible for all
supported PHP version. Currently the following versions are supported:

 - FrankenPHP 1.7.0 and PHP 8.4.10 (`ghcr.io/mintopia/php-frankenphp-base:8.4.10`)

The `latest` tag will always track the latest stable PHP version (8.4.10).

## Included Extensions

The following extensions are included:

 - bcmath
 - grpc
 - opentelemetry
 - pcntl
 - pdo
 - pdo_mysql
 - protobuf
 - redis

More will be added as required.

## Contributing

If you want to contribute, please raise a PR. I've only really intended this for my own projects, but if you're getting
some use and value out of it, that's awesome!

## License

MIT License

Copyright (c) 2025 Jessica Smith

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
