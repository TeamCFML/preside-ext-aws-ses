# AWS SES Integration for Preside

## Overview

This extension provides integration for AWS SES with Preside's email centre (Preside 10.8 and above).

Currently, the extension provides:

* A Message Centre service provider with configuration for sending email through AWS SES (SMTP)
* A webhook endpoint (`/awsses/hooks/`) for receiving and processing AWS SES webhooks for delivery & bounce notifications, etc.

See the [wiki](https://github.com/pixl8/preside-ext-aws-ses/wiki) for further documentation.

## Installation

Install the extension to your application via either of the methods detailed below (Git submodule / CommandBox) and then enable the extension by opening up the Preside developer console and entering:

```
extension enable preside-ext-aws-ses
reload all
```

### CommandBox (box.json) method

From the root of your application, type the following command:

```
box install preside-ext-aws-ses
```

### Git Submodule method

From the root of your application, type the following command:

```
git submodule add https://github.com/pixl8/preside-ext-aws-ses.git application/extensions/preside-ext-aws-ses
```