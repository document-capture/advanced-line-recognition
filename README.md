[![Crowdin](https://badges.crowdin.net/cdc-advanced-line-recognition/localized.svg)](https://crowdin.com)
# Advanced Line Recognition #

## Introduction ##
This repository contains an extension for [Continia Document Capture](https://www.continia.com/solutions/continia-document-capture/) module, which is a solution for scanning of invoices and other documents directly from inside Microsoft Dynamics Business Central/NAV! 

The code will be unregularly maintained or updated. 

## Remark ##
You can use this code as it is, without any warranty or support by me, [Continia Software A/S](https://www.continia.com "Continia Software"). 
You can use the Advanced Line Recognition on your own risk. 

**If you find issues in the code, please report these in the issues list here on Github.**

## Current Features ##
1. Find a field value by linking it to a previously found field and automatically calculating the distance and size
2. Find a field value by searching for a caption in the current position (sames procedure like on header fields - but only processed in the current position range)
3. Find a field value by the column heading (same procedure/training) like on default line fields. This enables the user to capture values based on the column that are not in the default line of the current position
4. Define a substitution value. If it was not able to find a value for a field you can define another field, who's value will be set as value for the field with the empty value.
5. Copy a value from the previous line. If it was not able to find a value for a field the system will use the value of this field from the previous line. 

## Documentation ##
At the moment there is no other documentation than this readme file.

## Available versions ##
The code will be updated unregularly for new versions of Document Capture. 
Going forward we will focus to enhance this module for Business Central al (application language), only. 
For a limited period we will also support the BC14 code to enable partners and customers to use the module on legacy versions of Business Central/NAV/Navision.

