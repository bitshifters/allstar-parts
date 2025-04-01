#!/usr/bin/python
import png,argparse,sys,math,arc

##########################################################################
##########################################################################

def save_file(data,path):
    if path is not None:
        with open(path,'wb') as f:
            f.write(''.join([chr(x) for x in data]))

##########################################################################
##########################################################################

def tunnel_func(x, y, param1, param2):
    d = math.sqrt( x*x + y*y )
    a = math.atan2( y, x )

    # magic formulas here
    if d>0.1:           # TODO: Make centre black.
        v = param1 / d      # TODO: Not const. r/tex_size = 32/128 = 0.25
    else:
        v = 0

    u = param2 * a / math.pi

    return [u,v]

def fancy_func1(x, y, param1, param2):
    d = math.sqrt( x*x + y*y )
    a = math.atan2( y, x )

    # magic formulas here
    if d!=0:
        u = math.cos( a )/d
        v = math.sin( a )/d
    else:
        u = 0
        v = 0

    return [u,v]

def two_planes_func(x,y, param1, param2):
    if y!=0:
        u = x/abs(y)
        v = 1/abs(y)
    else:
        u = 0
        v = 0

    return [u, v]

def iq_func1(x, y, param1, param2):
    r2 = x*x + y*y
    r = math.sqrt( r2 )         # make this const for rotated ortho texture

    u = x*math.cos(2*r) - y*math.sin(2*r)
    v = y*math.cos(2*r) + x*math.sin(2*r)

    return [u, v]

def iq_func2(x, y, param1, param2):             # spiral?
    r2 = x*x + y*y
    r = math.sqrt( r2 )
    a = math.atan2( y, x )

    if r!=0:
        u = 0.3/(r+0.5*x)
    else:
        u = 0

    v = 3*a/math.pi

    return [u, v]

def iq_func3(x, y, param1, param2):             # lobes?
    r2 = x*x + y*y
    r = math.sqrt( r2 )
    a = math.atan2( y, x )

    if r!=0:
        u = 0.02*y+0.03*math.cos(a*3)/r
        v = 0.02*x+0.03*math.sin(a*3)/r    
    else:
        u = 0
        v = 0

    return [u, v]

def iq_func4(x, y, param1, param2):             # folded plane?
    r2 = x*x + y*y
    r = math.sqrt( r2 )

    if r!=0:
        u = 0.1*x/(0.11+r*0.5)
        v = 0.1*y/(0.11+r*0.5)
    else:
        u = 0
        v = 0

    return [u, v]

def z_invert_func(x, y, param1, param2):
    r2 = x*x + y*y
    r = math.sqrt( r2 )

    if r2!=0:
        u = x/r2
        v = y/r2
    else:
        u = 0
        v = 0

    return [u, v]


def main(options):
    tw=options.tex_size or 256  # max u
    th=options.tex_size or 256  # max v

    pixel_data=[]

    if options.rgb_path is not None:

        png_result=png.Reader(filename=options.rgb_path).asRGBA8()

        print 'Image width: {0} height: {1}'.format(png_result[0],png_result[1])

        for row in png_result[2]:

            for i in range(0,len(row),8):
                rgba0 = [row[i+0],row[i+1],row[i+2],row[i+3]]
                rgba1 = [row[i+4],row[i+5],row[i+6],row[i+7]]

                u0=rgba0[0]
                v0=rgba0[1]

                u1=rgba1[0]
                v1=rgba1[1]

                pixel_data.append(u0 & 255)       # u
                pixel_data.append(u1 & 255)       # u
                pixel_data.append(v0 % th)        # v
                pixel_data.append(v1 % th)        # v

    else:
        sw=options.sw or 160
        sh=options.sh or 128
        print 'Image width: {0} height: {1}'.format(sw,sh)

        func_name = options.func_name or 'fancy_fun1'
        param1 = options.param1 or 1.0
        param2 = options.param2 or 1.0

        if options.square_aspect:
            aspect = float(sh) / float(sw)
        else:
            aspect = 1.0

        for j in range(0, sh):
            for i in range(0, sw, 2):

                # TODO: Figure out specifying the func and params.
                # TODO: Figure out screen aspect ratio shapes appear square.
                # TODO: Ability to skip a pixel (or always draw as 0).

                x = -1.0 + 2.0*i/sw
                y = -aspect + 2.0*aspect*float(j)/float(sh)

                [u0, v0] = eval(func_name)(x, y, param1, param2)

                x = -1.0 + 2.0*(i+1)/sw
                y = -aspect + 2.0*aspect*float(j)/float(sh)

                [u1, v1] = eval(func_name)(x, y, param1, param2)

                pixel_data.append(int(256.0*u0) & 255)       # u
                pixel_data.append(int(256.0*u1) & 255)       # u
                pixel_data.append(int(256.0*v0) % th)        # v
                pixel_data.append(int(256.0*v1) % th)        # v

    #assert(len(pixel_data)==sw*sh*2)
    save_file(pixel_data,options.output_path)
    print 'Wrote {0} bytes Arc data.'.format(len(pixel_data))


##########################################################################
##########################################################################

if __name__=='__main__':
    parser=argparse.ArgumentParser()

    parser.add_argument('-o',dest='output_path',metavar='FILE',help='output ARC data to %(metavar)s')
    parser.add_argument('--square-aspect',action='store_true',help='make table square aspect ratio')
    parser.add_argument('--sw',type=int,help='screen width')
    parser.add_argument('--sh',type=int,help='screen height')
    parser.add_argument('--tex-size',type=int,help='size of the texture')
    parser.add_argument('--rgb',dest='rgb_path',metavar='FILE',help='use %(metavar)s RGB png as [u,v] map')
    parser.add_argument('--func',dest='func_name',metavar='FUNC',help='use %(metavar)s as [u,v] math function')
    parser.add_argument('--param1',type=float,help='parameter 1 for func')
    parser.add_argument('--param2',type=float,help='parameter 2 for func')

    main(parser.parse_args())
