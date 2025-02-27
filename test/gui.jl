## Tests

using Gtk.ShortNames, Gtk.GConstants, Gtk.Graphics
import Gtk.deleteat!, Gtk.libgtk_version, Gtk.GtkToolbarStyle, Gtk.GtkFileChooserAction, Gtk.GtkResponseType

## for FileFilter
# This is just for testing, and be careful of garbage collection while using this
struct GtkFileFilterInfo
contains::Cint
filename::Ptr{Int8}
uri::Ptr{Int8}
display_name::Ptr{Int8}
mime_type::Ptr{Int8}
end
GtkFileFilterInfo(; filename = nothing, uri = nothing, display_name = nothing, mime_type = nothing) =
GtkFileFilterInfo(
    ( (isa(filename, AbstractString) ? Gtk.GtkFileFilterFlags.FILENAME : 0) |
    (isa(uri, AbstractString) ? Gtk.GtkFileFilterFlags.URI : 0) |
    (isa(display_name, AbstractString) ? Gtk.GtkFileFilterFlags.DISPLAY_NAME : 0) |
    (isa(mime_type, AbstractString) ? Gtk.GtkFileFilterFlags.MIME_TYPE : 0) ),
    isa(filename, AbstractString) ? pointer(filename) : C_NULL,
    isa(uri, AbstractString) ? pointer(uri) : C_NULL,
    isa(display_name, AbstractString) ? pointer(display_name) : C_NULL,
    isa(mime_type, AbstractString) ? pointer(mime_type) : C_NULL)

function name(filter::FileFilter)
nameptr = ccall((:gtk_file_filter_get_name, Gtk.libgtk), Ptr{Cchar}, (Ptr{GObject}, ), filter)
(nameptr == C_NULL) ? nothing : unsafe_string(nameptr)
end

needed(filter::FileFilter) =
ccall((:gtk_file_filter_get_needed, Gtk.libgtk), Cint, (Ptr{GObject}, ), filter)
import Base.filter
filter(filt::FileFilter, info::GtkFileFilterInfo) =
ccall((:gtk_file_filter_filter, Gtk.libgtk), UInt8, (Ptr{GObject}, Ref{GtkFileFilterInfo}), filt, info) != 0


# for subtyping from GObject
mutable struct MyWindow <: Window
    handle::Ptr{Gtk.GObject}
    testfield::String

    function MyWindow()

        w = Window("MyWindow")
        n = new(w.handle,"Test Field")
        Gtk.gobject_move_ref(n, w)
    end
end

# For testing callbacks
click(b::Button) = ccall((:gtk_button_clicked,Gtk.libgtk),Nothing,(Ptr{Gtk.GObject},),b)

@testset "gui" begin

wdth, hght = screen_size()
if !Sys.iswindows()
    @test wdth > 0 && hght > 0
end

@testset "Window" begin
w = Window("Window", 400, 300) |> showall
if !Sys.iswindows()
    # On windows, the wrong screen sizes are reported
    @test width(w) == 400
    @test height(w) == 300
    @test size(w) == (400, 300)
    wdth, hght = screen_size(w)
    @test wdth > 0 && hght > 0
end
G_.gravity(w,10) #GRAVITY_STATIC
sleep(0.1)
## Check Window positions
pos = G_.position(w)
if G_.position(w) != pos
    @warn("The Window Manager did move the Gtk Window in show")
end
G_.position(w, 100, 100)
sleep(0.1)
if G_.position(w) == pos
    @warn("The Window Manager did not move the Gtk Window when requested")
end
@test get_gtk_property(w, "title", AbstractString) == "Window"
set_gtk_property!(w, :title, "Window 2")
@test get_gtk_property(w, :title, AbstractString) == "Window 2"
visible(w,false)
@test visible(w) == false
visible(w,true)
@test visible(w) == true

gw = Gtk.gdk_window(w)
ox, oy = Gtk.get_origin(gw)

hide(w)
show(w)
grab_focus(w)

destroy(w); yield()
@test !get_gtk_property(w, :visible, Bool)
w=WeakRef(w)
GC.gc(); yield(); GC.gc()
#@test w.value === nothing    ### fails inside @testset
end

@testset "get/set property" begin
    w = Window("Window", 400, 300) |> showall
    @test w.title[String] == "Window"
    @test w.visible[Bool]
    w.visible[Bool] = false
    @test w.visible[Bool] == false
    destroy(w)
end

@testset "change Window size" begin
if  libgtk_version >= v"3.16.0"
  w = Window("Window", 400, 300)
  fullscreen(w)
  sleep(1)
  unfullscreen(w)
  sleep(1)
  maximize(w)
  sleep(1)
  if !get_gtk_property(w, :is_maximized, Bool)
      @warn("The Window Manager did not maximize the Gtk Window when requested")
  end
  unmaximize(w)
  sleep(1)
  @test !get_gtk_property(w, :is_maximized, Bool)
  destroy(w)
end
end

@testset "Frame" begin
w = Window(
    Frame(),
    "Frame", 400, 400)
widgets=[f for f in w] # test iteration over GtkBin
@test length(widgets)==1
showall(w)
destroy(w)
end

@testset "Initially Hidden Canvas" begin
nb = Notebook()
@test hasparent(nb)==false
vbox = Gtk.GtkBox(:v)
c = Canvas()
push!(nb, vbox, "A")
push!(nb, c, "B")
insert!(nb, 2, Label("Something in the middle"), "A*")
pushfirst!(nb, Label("Something at the beginning"), "First")
splice!(nb, 3)
w = Window("TestDataViewer",600,600)
@test pagenumber(nb,c)==3
push!(w,nb)
@test parent(nb)==w
showall(w)
destroy(w)
end

@testset "Labelframe" begin
f = Frame("Label")
w = Window(f, "Labelframe", 400, 400)
set_gtk_property!(f,:label,"new label")
@test get_gtk_property(f,:label,AbstractString) == "new label"
showall(w)
destroy(w)
end

@testset "notebook" begin
nb = Notebook()
w = push!(Window("Notebook"),nb)
push!(nb, Button("o_ne"), "tab _one")
push!(nb, Button("t_wo"), "tab _two")
push!(nb, Button("th_ree"), "tab t_hree")
push!(nb, "fo_ur", "tab _four")
showall(w)
@test length(nb) == 4
set_gtk_property!(nb,:page,2)
@test get_gtk_property(nb,:page,Int) == 2
showall(w)
destroy(w)
end

@testset "Panedwindow" begin
w = Window("Panedwindow", 400, 400)
pw = Paned(:h)
pw2 = Paned(:v)
push!(w, pw)
push!(pw, Button("one"))
push!(pw, pw2)
@test pw[2]==pw2
pw2[1]=Button("two")
pw2[2,true,false]=Button("three")
showall(w)
destroy(w)
end

@testset "Layout" begin
w = Window("Layout", 400, 400)
l = Layout(600,600)
push!(w,l)
l[300,300]=Button("Button")
s=size(l)
@test width(l)==600
@test height(l)==600
showall(w)
destroy(w)
end

@testset "Iteration and toplevel" begin
## example of last in first covered
## Create this GUI, then shrink window with the mouse
f = Gtk.GtkBox(:v)
w = Window(f, "Last in, first covered", 400, 400)

g1 = Gtk.GtkBox(:h)
g2 = Gtk.GtkBox(:h)
push!(f,g1)
push!(f,g2)
@test f[1]==g1

b11 = Button("first")
push!(g1, b11)
b12 = Button("second")
push!(g1, b12)
b21 = Button("first")
push!(g2, b21)
b22 = Button("second")
push!(g2, b22)

strs = ["first", "second"]
i = 1
for child in g1
    @test get_gtk_property(child,:label,AbstractString) == strs[i]
    @test toplevel(child) == w
    i += 1
end
set_gtk_property!(g1,:pack_type,b11,0) #GTK_PACK_START
set_gtk_property!(g1,:pack_type,b12,0) #GTK_PACK_START
set_gtk_property!(g2,:pack_type,b21,1) #GTK_PACK_END
set_gtk_property!(g2,:pack_type,b22,1) #GTK_PACK_END
@test get_gtk_property(g1,:pack_type, b11, Int) == 0

## Now shrink window
showall(w)
destroy(w)
end

@testset "ButtonBox" begin
## ButtonBox
bb = ButtonBox(:h)
w = Window(bb, "ButtonBox")
cancel = Button("Cancel")
ok = Button("OK")
append!(bb, [cancel,ok])

# Expander
delete!(w, bb)
ex = Expander(bb, "Some buttons")
push!(w, ex)
showall(w)
destroy(w)
end

@testset "Grid" begin
    grid = Grid()
    w = Window(grid, "Grid", 400, 400)
    b=Button("2,2")
    grid[2,2] = b
    @test grid[2,2] == b
    grid[2,3] = Button("2,3")
    grid[1,1] = "grid"
    grid[3,1:3] = Button("Tall button")
    insert!(grid,1,:top)
    insert!(grid,3,:bottom)
    insert!(grid,grid[1,2],:right)
    libgtk_version >= v"3.10.0" && deleteat!(grid,1,:row)
    showall(w)
    empty!(grid)
    destroy(w)
end


## Widgets

@testset "button, label" begin
w = Window("Widgets")
f = Gtk.GtkBox(:v); push!(w,f)
l = Label("label"); push!(f,l)
b = Button("button"); push!(f,b)

set_gtk_property!(l,:label,"new label")
@test get_gtk_property(l,:label,AbstractString) == "new label"
set_gtk_property!(b,:label,"new label")
@test get_gtk_property(b,:label,AbstractString) == "new label"

counter = 0
id = signal_connect(b, "clicked") do widget
    counter::Int += 1
end
@test signal_handler_is_connected(b, id)

@test counter == 0
click(b)
@test counter == 1
signal_handler_block(b, id)
click(b)
@test counter == 1
signal_handler_unblock(b, id)
click(b)
@test counter == 2
signal_handler_disconnect(b, id)
click(b)
@test counter == 2
showall(w)
destroy(w)
end

@testset "Button with custom icon (& Pixbuf)" begin
icon = Matrix{Gtk.RGB}(undef, 40, 20)
fill!(icon, Gtk.RGB(0,0xff,0))
icon[5:end-5, 3:end-3] .= Ref(Gtk.RGB(0,0,0xff))
pb=Pixbuf(data=icon, has_alpha=false)
@test eltype(pb) == Gtk.RGB
@test size(pb) == (40, 20)
@test pb[1,1].g==0xff
pb[10,10]=Gtk.RGB(0,0,0)
pb[20:30,1:5]=Gtk.RGB(0xff,0,0)
w = Window(Button(Image(pb)), "Icon button", 60, 40)
showall(w)
pb2=copy(pb)
@test size(pb2,2) == size(pb)[2]
pb3=Gtk.slice(pb2,11:20,11:20)
@test size(pb3) == (10,10)
fill!(pb3,Gtk.RGB(0,0,0))
destroy(w)
end

@testset "Transparent pixbuf" begin
icon = Matrix{Gtk.RGBA}(undef, 40, 20)
fill!(icon, Gtk.RGBA(0,0xff,0, 0xff))
icon[5:end-5, 3:end-3] .= Ref(Gtk.RGBA(0,0,0xff,0x80))
pb=Pixbuf(data=icon, has_alpha=true)
@test eltype(pb) == Gtk.RGBA
end

@testset "Icon theme" begin
img = Image(; icon_name = "document-open", size=:BUTTON)
icon_theme = Gtk.icon_theme_get_default()
pb=Gtk.icon_theme_load_icon_for_scale(icon_theme, "document-open", 60, 60, Gtk.GConstants.GtkIconLookupFlags.GTK_ICON_LOOKUP_NO_SVG)
@test isa(pb,GdkPixbuf)
end

@testset "checkbox" begin
w = Window("Checkbutton")
check = CheckButton("check me"); push!(w,check)
set_gtk_property!(check,:active,true)
@test get_gtk_property(check,:active,AbstractString) == "TRUE"
set_gtk_property!(check,:label,"new label")
@test get_gtk_property(check,:label,AbstractString) == "new label"
#ctr = 0
#tk_bind(check, "command", cb)
#tcl(check, "invoke")
#@test ctr == 1
showall(w)
destroy(w)
end

@testset "radio" begin
choices = ["choice one", "choice two", "choice three", RadioButton("choice four"), Label("choice five")]
w = Window("Radio")
f = Gtk.GtkBox(:v); push!(w,f)
r = Vector{RadioButton}(undef, 3)
r[1] = RadioButton(choices[1]); push!(f,r[1])
r[2] = RadioButton(r[1],choices[2]); push!(f,r[2])
r[3] = RadioButton(r[2],choices[3],active=true); push!(f,r[3])
@test [get_gtk_property(b,:active,Bool) for b in r] == [false, false, true]
set_gtk_property!(r[1],:active,true)
@test [get_gtk_property(b,:active,Bool) for b in r] == [true, false, false]
showall(w)
destroy(w)

r = RadioButtonGroup(choices,2)
@test length(r) == 5
@test sum([get_gtk_property(b,:active,Bool) for b in r]) == 1
itms = Vector{Any}(undef,length(r))
for (i,e) in enumerate(r)
    itms[i] = try
            get_gtk_property(e,:label,AbstractString)
        catch
            e[1]
        end
end
@test setdiff(choices, itms) == [choices[4],]
@test setdiff(itms, choices) == ["choice four",]
@test get_gtk_property(get_gtk_property(r,:active),:label,AbstractString) == choices[2]
w = Window(r,"RadioGroup")|>showall
destroy(w)
end

@testset "ToggleButton" begin
tb = ToggleButton("Off")
w = Window(tb, "ToggleButton")|>showall
function toggled(ptr,evt,widget)
    state = get_gtk_property(widget,:label,AbstractString)
    if state == "Off"
        set_gtk_property!(widget,:label,"On")
    else
        set_gtk_property!(widget,:label,"Off")
    end
    convert(Int32,true)
end
on_signal_button_press(toggled, tb)
press=Gtk.GdkEventButton(Gtk.GdkEventType.BUTTON_PRESS, Gtk.gdk_window(tb), Int8(0), UInt32(0), 0.0, 0.0, convert(Ptr{Float64},C_NULL), UInt32(0), UInt32(1), C_NULL, 0.0, 0.0)
signal_emit(tb, "button-press-event", Bool, press)
release=Gtk.GdkEventButton(Gtk.GdkEventType.BUTTON_RELEASE, Gtk.gdk_window(tb), Int8(0), UInt32(0), 0.0, 0.0, convert(Ptr{Float64},C_NULL), UInt32(0), UInt32(1), C_NULL, 0.0, 0.0)
signal_emit(tb, "button-release-event", Bool, release)
## next time just use "gtk_button_clicked", mkay?
destroy(w)
end

@testset "ToggleButton repeat 1" begin
tb = ToggleButton("Off")
w = Window(tb, "ToggleButton")|>showall
# TODO: uncomment these next lines
on_signal_button_press(tb) do ptr, evt, widget
    state = get_gtk_property(widget,:label,AbstractString)
    if state == "Off"
        set_gtk_property!(widget,:label,"On")
    else
        set_gtk_property!(widget,:label,"Off")
    end
    Int32(true)
end
press=Gtk.GdkEventButton(Gtk.GdkEventType.BUTTON_PRESS, Gtk.gdk_window(tb), Int8(0), UInt32(0), 0.0, 0.0, convert(Ptr{Float64},C_NULL), UInt32(0), UInt32(1), C_NULL, 0.0, 0.0)
signal_emit(tb, "button-press-event", Bool, press)
release=Gtk.GdkEventButton(Gtk.GdkEventType.BUTTON_RELEASE, Gtk.gdk_window(tb), Int8(0), UInt32(0), 0.0, 0.0, convert(Ptr{Float64},C_NULL), UInt32(0), UInt32(1), C_NULL, 0.0, 0.0)
signal_emit(tb, "button-release-event", Bool, release)
# next time just use "gtk_button_clicked", mkay?
destroy(w)
end

@testset "ToggleButton repeat 2" begin
tb = ToggleButton("Off")
w = Window(tb, "ToggleButton")|>showall
signal_connect(tb, :button_press_event) do widget, evt
    state = get_gtk_property(widget,:label,AbstractString)
    if state == "Off"
        set_gtk_property!(widget,:label,"On")
    else
        set_gtk_property!(widget,:label,"Off")
    end
    Int32(true)
end
press=Gtk.GdkEventButton(Gtk.GdkEventType.BUTTON_PRESS, Gtk.gdk_window(tb), Int8(0), UInt32(0), 0.0, 0.0, convert(Ptr{Float64},C_NULL), UInt32(0), UInt32(1), C_NULL, 0.0, 0.0)
signal_emit(tb, "button-press-event", Bool, press)
release=Gtk.GdkEventButton(Gtk.GdkEventType.BUTTON_RELEASE, Gtk.gdk_window(tb), Int8(0), UInt32(0), 0.0, 0.0, convert(Ptr{Float64},C_NULL), UInt32(0), UInt32(1), C_NULL, 0.0, 0.0)
signal_emit(tb, "button-release-event", Bool, release)
## next time just use "gtk_button_clicked", mkay?
destroy(w)
end

@testset "LinkButton" begin
b = LinkButton("https://github.com/JuliaLang/Gtk.jl", "Gtk.jl")
w = Window(b, "LinkButton")|>showall
destroy(w)
end

@testset "VolumeButton" begin
b = VolumeButton(0.3)
w = Window(b, "VolumeButton", 50, 50)|>showall
destroy(w)
end

@testset "ColorButton" begin
b = ColorButton(Gtk.GdkRGBA(0, 0.8, 1.0, 0.3))
w = Window(b, "ColorButton", 50, 50)|>showall
GAccessor.rgba(ColorChooser(b), GLib.mutable(Gtk.GdkRGBA(0, 0, 0, 0)))
destroy(w)
end

@testset "combobox" begin
combo = ComboBoxText()
choices = ["Strawberry", "Vanilla", "Chocolate"]
for c in choices
    push!(combo, c)
end
c = cells(CellLayout(combo))
set_gtk_property!(c[1],"max_width_chars", 5)

w = Window(combo, "ComboGtkBoxText")|>showall
lsl = ListStoreLeaf(combo)
@test length(lsl) == 3
empty!(combo)
@test length(lsl) == 0

destroy(w)

combo = ComboBoxText(true)
for c in choices
    push!(combo, c)
end
pushfirst!(combo, "Rocky road")
insert!(combo, 3, "Pistachio")
delete!(combo, 3)
w = Window(combo, "ComboBoxText with entry")|>showall
destroy(w)
end

@testset "slider/scale" begin
sl = Scale(true, 1:10)
w = Window(sl, "Scale")|>showall
G_.value(sl, 3)
@test G_.value(sl) == 3
adj = Adjustment(sl)
@test get_gtk_property(adj,:value,Float64) == 3
set_gtk_property!(adj,:upper,11)
destroy(w)
end

@testset "spinbutton" begin
sp = SpinButton(1:10)
w = Window(sp, "SpinButton")|>showall
G_.value(sp, 3)
@test G_.value(sp) == 3
destroy(w)
end

@testset "progressbar" begin
pb = ProgressBar()
w = Window(pb, "Progress bar")|>showall
set_gtk_property!(pb,:fraction,0.7)
@test get_gtk_property(pb,:fraction,Float64) == 0.7
pulse(pb)
destroy(w)
end

@testset "spinner" begin
s = Spinner()
w = Window(s, "Spinner")|>showall
start(s)
@test get_gtk_property(s,:active,Bool) == true
stop(s)
@test get_gtk_property(s,:active,Bool) == false

destroy(w)
end

@testset "Entry" begin
e = Entry()
w = Window(e, "Entry")|>showall
set_gtk_property!(e,:text,"initial")
set_gtk_property!(e,:sensitive,false)

activated = false
signal_connect(e, :activate) do widget
    activated = true
end
signal_emit(e, :activate, Nothing)
@test activated

destroy(w)
end

@testset "Statusbar" begin
vbox = Gtk.GtkBox(:v)
w = Window(vbox, "Statusbar")
global sb = Statusbar()  # closures are not yet c-callable
push!(vbox, sb)
ctxid = Gtk.context_id(sb, "Statusbar example")
bpush = Button("push item")
bpop = Button("pop item")
push!(vbox, bpush)
push!(vbox, bpop)
showall(w)
global sb_count = 1
function cb_sbpush(ptr,evt,id)
    push!(sb, id, string("Item ", sb_count))
    sb_count += 1
    convert(Int32,false)
end
function cb_sbpop(ptr,evt,id)
    pop!(sb, id)
    convert(Int32,false)
end
on_signal_button_press(cb_sbpush, bpush, false, ctxid)
on_signal_button_press(cb_sbpop, bpop, false, ctxid)

click(bpush)
click(bpop)
empty!(sb,ctxid)
destroy(w)
end

@testset "Canvas & AspectFrame" begin
c = Canvas()
f = AspectFrame(c, "AspectFrame", 0.5, 1, 0.5)
w = Window(f, "Canvas")|>showall
c.draw = function(_)
    ctx = getgc(c)
    set_source_rgb(ctx, 1.0, 0.0, 0.0)
    paint(ctx)
end
draw(c)
destroy(w)
end

@testset "SetCoordinates" begin
    win = Window() |> (cnvs = Canvas(300, 280))
    draw(cnvs) do c
        set_coordinates(getgc(c), BoundingBox(0, 1, 0, 1))
    end
    Gtk.showall(win)
    sleep(0.5)
    mtrx = Gtk.Cairo.get_matrix(getgc(cnvs))
    @test mtrx.xx == 300
    @test mtrx.yy == 280
    @test mtrx.xy == mtrx.yx == mtrx.x0 == mtrx.y0 == 0
    surf = Gtk.cairo_surface(cnvs)
    a = Gtk.allocation(cnvs)
    @test isa(a,Gtk.GdkRectangle)
end

@testset "Menus" begin
file = MenuItem("_File")
filemenu = Menu(file)
new_ = MenuItem("New")
idnew = signal_connect(new_, :activate) do widget
    println("New!")
end
push!(filemenu, new_)
open_ = MenuItem("Open")
push!(filemenu, open_)
push!(filemenu, SeparatorMenuItem())
quit = MenuItem("Quit")
push!(filemenu, quit)
mb = MenuBar()
push!(mb, file)  # notice this is the "File" item, not filemenu
win = Window(mb, "Menus", 200, 40)|>showall
destroy(win)
end

@testset "Popup menu" begin
contrast = MenuItem("Adjust contrast...")
popupmenu = Menu()
push!(popupmenu, contrast)
c = Canvas()
win = Window(c, "Popup")|>showall
showall(popupmenu)
c.mouse.button3press = (widget,event) -> popup(popupmenu, event)
destroy(win)
end

## Text
#w = Window("Text")
#pack_stop_propagate(w)
#f = Frame(w); pack(f, {:expand=>true, :fill=>"both"})
#txt = Text(w)
#scrollbars_add(f, txt)
#set_value(txt, "new text\n")
#@test get_value(txt) == "new text\n"
#destroy(w)

## tree. Listbox
#w = Window("Listbox")
#pack_stop_propagate(w)
#f = Frame(w); pack(f, {:expand=>true, :fill=>"both"})
#tr = Treeview(f, choices)
#scrollbars_add(f, tr)
#set_value(tr, 2)
#@test get_value(tr)[1] == choices[2]
#set_items(tr, choices[1:2])
#destroy(w)


## tree grid
#w = Window("Array")
#pack_stop_propagate(w)
#f = Frame(w); pack(f, {:expand=>true, :fill=>"both"})
#tr = Treeview(f, hcat(choices, choices))
#tree_key_header(tr, "right"); tree_key_width(tr, 50)
#tree_headers(tr, ["left"], [50])
#scrollbars_add(f, tr)
#set_value(tr, 2)
#@test get_value(tr)[1] == choices[2]
#destroy(w)

@testset "File Chooser" begin
    dlg = FileChooserDialog("Select file", Null(), GtkFileChooserAction.OPEN,
                            (("_Cancel", GtkResponseType.CANCEL),
                             ("_Open", GtkResponseType.ACCEPT)))
    destroy(dlg)
end

@testset "Color Chooser" begin
dlg = ColorChooserDialog("Select color", Null())
destroy(dlg)
end

@testset "List view" begin
ls=ListStore(Int32,Bool)
push!(ls,(42,true))
ls[1,1]=44
push!(ls,(33,true))
pushfirst!(ls,(22,false))
popfirst!(ls)
@test size(ls)==(2,2)
insert!(ls, 2, (35, false))
tv=TreeView(TreeModel(ls))
r1=CellRendererText()
r2=CellRendererToggle()
c1=TreeViewColumn("A", r1, Dict([("text",0)]))
c2=TreeViewColumn("B", r2, Dict([("active",1)]))
push!(tv,c1)
push!(tv,c2)
delete!(tv, c1)
insert!(tv, 1, c1)
w = Window(tv, "List View")|>showall

## selection

selmodel = G_.selection(tv)
@test hasselection(selmodel) == false
select!(selmodel, Gtk.iter_from_index(ls, 1))
@test hasselection(selmodel) == true
iter = selected(selmodel)
@test Gtk.index_from_iter(ls, iter) == 1
@test ls[iter, 1] == 44
deleteat!(ls, iter)
select!(selmodel, Gtk.iter_from_index(ls, 1))
iter = selected(selmodel)
@test ls[iter, 1] == 35

G_.mode(selmodel,Gtk.GConstants.GtkSelectionMode.MULTIPLE)
selectall!(selmodel)
iters = Gtk.selected_rows(selmodel)
@test length(iters) == 2
@test ls[iters[1],1] == 35
unselectall!(selmodel)

tmSorted=TreeModelSort(ls)
G_.model(tv,tmSorted)
G_.sort_column_id(TreeSortable(tmSorted),0,GtkSortType.ASCENDING)
it = convert_child_iter_to_iter(tmSorted,Gtk.iter_from_index(ls, 1))
G_.mode(selmodel,Gtk.GConstants.GtkSelectionMode.SINGLE)
select!(selmodel, it)
iter = selected(selmodel)
@test TreeModel(tmSorted)[iter, 1] == 35

empty!(ls)

destroy(w)
end


@testset "Tree view" begin
ts=TreeStore(AbstractString)
iter1 = push!(ts,("one",))
iter2 = push!(ts,("two",),iter1)
iter3 = push!(ts,("three",),iter2)
tv=TreeView(TreeModel(ts))
r1=CellRendererText()
c1=TreeViewColumn("A", r1, Dict([("text",0)]))
push!(tv,c1)
w = Window(tv, "Tree View")|>showall
iter = Gtk.iter_from_index(ts, [1])
ts[iter,1] = "ONE"
@test ts[iter,1] == "ONE"
@test map(i -> ts[i, 1], Gtk.TreeIterator(ts, iter)) == ["two", "three"]
@test Gtk.iter_n_children(TreeModel(ts), iter)==1

destroy(w)
end

@testset "Toolbar" begin
tb1 = ToolButton("gtk-open")
tb2 = ToolButton("gtk-new")
tb3 = ToolButton("gtk-media-next")
toolbar = Toolbar()
push!(toolbar,tb1)
pushfirst!(toolbar,tb2)
push!(toolbar,tb3)
push!(toolbar,SeparatorToolItem(), ToggleToolButton("gtk-open"), MenuToolButton("gtk-new"))
@test toolbar[0]==tb2  # FIXME: uses zero based indexing
@test length(toolbar)==6
G_.style(toolbar,GtkToolbarStyle.BOTH)
w = Window(toolbar, "Toolbar")|>showall
destroy(w)
end

@testset "FileFilter" begin
emptyfilter = FileFilter()
@test name(emptyfilter) == nothing

fname = "test.csv"
fdisplay = "test.csv"
fmime = "text/csv"
csvfileinfo = GtkFileFilterInfo(; filename = fname, display_name = fdisplay, mime_type = fmime)
println("file info contains: ", csvfileinfo.contains)
# Should reject anything really
@test filter(emptyfilter, csvfileinfo) == false
# Name is set internally as the pattern if no name is given
csvfilter1 = FileFilter("*.csv")
@test name(csvfilter1) == "*.csv"
@test needed(csvfilter1) & Gtk.GtkFileFilterFlags.DISPLAY_NAME > 0
@test filter(csvfilter1, csvfileinfo)
csvfilter2 = FileFilter("*.csv"; name="Comma Separated Format")
@test name(csvfilter2) == "Comma Separated Format"
@test needed(csvfilter2) & Gtk.GtkFileFilterFlags.DISPLAY_NAME > 0
@test filter(csvfilter2, csvfileinfo)

if !Sys.iswindows()#filter fails on windows 7
    csvfilter3 = FileFilter(; mimetype="text/csv")
    @test name(csvfilter3) == "text/csv"
    @test needed(csvfilter3) & Gtk.GtkFileFilterFlags.MIME_TYPE > 0
    @test filter(csvfilter3, csvfileinfo)
end

csvfilter4 = FileFilter(; pattern="*.csv", mimetype="text/csv")
# Pattern takes precedence over mime-type, causing mime-type to be ignored
@test name(csvfilter4) == "*.csv"
@test needed(csvfilter4) & Gtk.GtkFileFilterFlags.MIME_TYPE == 0
@test filter(csvfilter4, csvfileinfo)
end

# Canvas mouse callback stack operations
@testset "Canvas mouse callback stack operations" begin
c = Canvas()
w = Window(c)
showall(w)
io = IOBuffer()
c.mouse.button1press = (widget,evt) -> println(io, "cb1_1")
c.mouse.button2press = (widget,evt) -> println(io, "cb2_1")
press1=Gtk.GdkEventButton(Gtk.GdkEventType.BUTTON_PRESS, Gtk.gdk_window(c), Int8(0), UInt32(0), 0.0, 0.0, convert(Ptr{Float64},C_NULL), UInt32(0), UInt32(1), C_NULL, 0.0, 0.0)
press2=Gtk.GdkEventButton(Gtk.GdkEventType.BUTTON_PRESS, Gtk.gdk_window(c), Int8(0), UInt32(0), 0.0, 0.0, convert(Ptr{Float64},C_NULL), UInt32(0), UInt32(2), C_NULL, 0.0, 0.0)
signal_emit(c, "button-press-event", Bool, press1)
signal_emit(c, "button-press-event", Bool, press2)
push!((c.mouse,:button1press), (widget,evt) -> println(io, "cb1_2"))
signal_emit(c, "button-press-event", Bool, press1)
signal_emit(c, "button-press-event", Bool, press2)
push!((c.mouse,:button2press), (widget,evt) -> println(io, "cb2_2"))
signal_emit(c, "button-press-event", Bool, press1)
signal_emit(c, "button-press-event", Bool, press2)
pop!((c.mouse,:button1press))
signal_emit(c, "button-press-event", Bool, press1)
signal_emit(c, "button-press-event", Bool, press2)
str = String(take!(io))
@test str == "cb1_1\ncb2_1\ncb1_2\ncb2_1\ncb1_2\ncb2_2\ncb1_1\ncb2_2\n"

c.mouse.scroll = (widget,event) -> println(io, "scrolling")
scroll = Gtk.GdkEventScroll(Gtk.GdkEventType.SCROLL, Gtk.gdk_window(c), Int8(0), UInt32(0), 0.0, 0.0, UInt32(0), Gtk.GdkScrollDirection.UP, convert(Ptr{Float64},C_NULL), 0.0, 0.0, 0.0, 0.0)
signal_emit(c, "scroll-event", Bool, scroll)
str = String(take!(io))
@test str == "scrolling\n"

destroy(w)
end

@testset "overlay" begin
c = Canvas()
o = Overlay(c)
push!(o,Button("Button"))
w = Window(o, "overlay")|>showall
destroy(w)
end

# CSS

@testset "CssProviderLeaf(filename=\"...\")" begin
    style_file = joinpath(dirname(@__FILE__), "style_test.css")

    l = Label("I am some large blue text!")
    w = Window(l)

    screen   = Gtk.GAccessor.screen(w)
    provider = CssProviderLeaf(filename=style_file)

    ccall((:gtk_style_context_add_provider_for_screen, Gtk.libgtk), Nothing,
          (Ptr{Nothing}, Ptr{GObject}, Cuint),
          screen, provider, 1)

    showall(w)

    ### add css tests here

    destroy(w)
end

@testset "Builder" begin
b=Builder(;filename="test.glade")
widgets = [w for w in b]
@test length(widgets)==length(b)
button = b["a_button"]
@test isa(button,Button)
@test isa(b[1],Gtk.GtkWidget)

@test_throws ErrorException b2 = Builder(;filename="test2.glade")
end

@testset "Subtyping from GObject" begin

w = MyWindow()
showall(w)

@test w.testfield == "Test Field"
w.testfield = "setproperty!"
@test w.testfield == "setproperty!"

@test w.title[String] == "MyWindow"
w.title[String] = "setindex!"
@test w.title[String] == "setindex!"
@test typeof(w.title) <: Gtk.GLib.FieldRef

destroy(w)

end

@testset "Tree" begin
    include("tree.jl")
end

end  # testset gui
