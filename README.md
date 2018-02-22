![Volta logo](https://raw.githubusercontent.com/robo-fish/Volta/master/app/resources/graphics/Volta.iconset/icon_256x256.png)

# Volta

Volta is a simple circuit design application that I developed between 2007 and 2013. Volta is the successor of [MI-SUGAR](https://github.com/robo-fish/MI-SUGAR). Just as with MI-SUGAR, you can draw a circuit, capture it as a SPICE-compatible netlist, run the netlist in circuit simulator, and plot the simulation results. Unlike MI-SUGAR it features an XML file format, which is used both for circuit files (including SPICE netlist with analysis commands) and for component library files. A library file can define electric components with custom shapes expressed in a subset of the vector graphics format SVG.

The code in this repository is based on the source code of the unreleased version 1.2.4 (the last publicly released version of Volta was 1.2.3 in July 2013). There are already numerous changes in the initial revision, from AppKit API adaptations to rewriting Objective-C code in Swift.

## How to Build

### Dependencies

You need to build the [Ngspice](http://ngspice.sourceforge.net) binary and copy it inside the project folder. There are prebuilt binaries for macOS available for download

Copy the binary *ngspice* to `<Volta project folder>/components/simulator/resources/` of the Volta project folder.

Make sure the binary file is exactly named *ngspice*.

Unless you want to use the circuit simulation function of Volta you can create a dummy file *ngspice* with these two lines in Terminal:

    cd <Volta project folder>/components/simulator/resources
    touch ngspice

### Xcode

In Xcode, open the project *Volta.xcodeproj* located in the `<Volta project folder>/app/` folder.
Xcode 9.2 on macOS 10.13 should work.

## License

The license for this source code release is [GPL 3](https://www.gnu.org/licenses/gpl-3.0.html).

![GPL3](https://www.gnu.org/graphics/gplv3-88x31.png)
