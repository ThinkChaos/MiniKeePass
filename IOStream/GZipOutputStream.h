/*
 * Copyright 2017-2019 Innervate UG & Co. KG. All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "OutputStream.h"
#import <Foundation/Foundation.h>
#import <zlib.h>

#define GZIP_OUTPUT_BUFFERSIZE 16384

@interface GZipOutputStream : OutputStream {
  OutputStream *outputStream;

  z_stream zstream;
  uint8_t buffer[GZIP_OUTPUT_BUFFERSIZE];
}

- (id)initWithOutputStream:(OutputStream *)stream;

@end
