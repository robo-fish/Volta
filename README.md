![Volta logo](https://raw.githubusercontent.com/robo-fish/Volta/master/app/resources/Images.xcassets/AppIcon.appiconset/icon_256x256.png)
# Volta

Volta is a simple circuit design application that I developed between 2007 and 2013. Volta is the successor of [MI-SUGAR](https://github.com/robo-fish/MI-SUGAR). Just as with MI-SUGAR, you can draw a circuit, capture it as a SPICE-compatible netlist, run the netlist in circuit simulator, and plot the simulation results. Unlike MI-SUGAR it features an XML file format, a plug-in based modular structure, and supports modern macOS features. The XML file format is used both for circuit files (including SPICE netlist with analysis commands) and for component library files. A library file can define electric components whose shapes are defined in a subset of the vector graphics format [SVG](https://www.w3.org/Graphics/SVG/).

The code in this repository is based on the source code of the unreleased version 1.2.4 (the last publicly released version of Volta was 1.2.3 in July 2013). There are already numerous changes in the initial revision, from AppKit API adaptations to rewriting Objective-C code in Swift.

For more information about Volta visit the [wiki page on robo.fish](https://robo.fish/wiki/index.php?title=Volta).

## How to Build

### Dependencies

#### Make tools

If necessary, install the command line build tools *autoconf*, *automake*, and *libtool* via [Homebrew](https://brew.sh/index.html). Homebrew also takes care of installing the Xcode command line tools.

#### Ngspice

[Ngspice](http://ngspice.sourceforge.net) is the third-party circuit simulator that Volta uses. Download the tarball (\*.tar.gz) of version 27. There is a prebuilt binary for macOS available but it requires X Window to be installed, which we don't need. Open Terminal and *cd* to the download folder. Now build the Ngspice binary with the aforementioned build tools copy the generated executable into the Volta project folder:

    tar -xzf ngspice-27.tar.gz
    cd ngspice-27
    ./configure --without-x --disable-debug
    make
    cp src/ngspice <Volta project folder>/components/simulator/resources/

If you don't want to use the circuit simulation function of Volta you can create a dummy *ngspice* file instead:

    cd <Volta project folder>/components/simulator/resources
    touch ngspice


### Building Volta

In [Xcode](https://developer.apple.com/xcode), open the project *Volta.xcodeproj* located in the `<Volta project folder>/app/` folder.
Xcode 9.2 on macOS 10.13 should work. The Volta project contains many targets; frameworks, bundles, test applications, and the Volta application. In the popup button select the *Volta* target if it is not selected already.

## License


The license for this source code release is GPL 3.

[![GPL3](https://www.gnu.org/graphics/gplv3-88x31.png)](https://www.gnu.org/licenses/gpl-3.0.html)
