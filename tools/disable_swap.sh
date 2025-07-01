#!/bin/bash

swapoff -a && sed -i '/^[^#].*[\t\ ]swap[\t\ ]/ s/^/#/' /etc/fstab
