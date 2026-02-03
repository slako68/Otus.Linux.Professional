#!/bin/bash

lvremove -y /dev/vg_root/lv_root
vgremove -y /dev/vg_root
pvremove -y /dev/vdb