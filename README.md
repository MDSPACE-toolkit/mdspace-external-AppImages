# mdspace-external-AppImages

## Overview

This project provides individual portable **AppImage** executables, one per external tool, producing one self-contained executable that includes all required components. By bundling all required binaries and libraries, the AppImage allows the full workflow to run on most Linux systems without installation.

## What Is an AppImage?

An AppImage is a self-contained executable file for Linux. It includes all necessary runtime components, so users can run the application without installing system packages or managing version conflicts. After download, it typically only requires making the file executable.

## Included Tools

This project distributes one AppImage per tool. The provided executables include:

* **Xmipp Reconstruct Fourier** — routines for Fourier-based reconstruction in structural analysis.
* **Xmipp Image Convert** — tools for converting and manipulating scientific image formats.
* **SMOG 2** — tools for generating structure-based models for molecular simulation.
* **ELNEMO** — utilities for analyzing elastic network models.
* **GENESIS** — simulation engine for molecular dynamics tasks.

Each tool has its own AppImage executable, and each AppImage contains all dependencies required to run that specific tool.

## Usage

See the official MDSpace software documentation for instructions on how these individual AppImages are detected and used by the MDSpace application (also distributed as an AppImage).
