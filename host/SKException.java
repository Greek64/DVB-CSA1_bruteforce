/*
DVB-CSA1 Brute-force FPGA Implementation
Copyright (C) 2018  Ioannis Daktylidis

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/*
Special Exception Class thrown by TransportStreamParser Class.
This exception signals that not enough samples encrypted with the same key were found before
the first packet encrypted with the next key was encountered.
SKException stands for Scrambling Key Exception.
*/
public class SKException extends Exception {
    public SKException(){
    }

    public SKException(String msg) {
        super(msg);
    }

    public SKException(Throwable cause) {
        super(cause);
    }

    public SKException(String msg, Throwable cause) {
        super(msg, cause);
    }
}
