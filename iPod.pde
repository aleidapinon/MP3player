//Lib interfaz
import controlP5.*;

//Lib audio
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;

//Lib java
import java.util.*;
import java.net.InetAddress;
import javax.swing.*;
import javax.swing.filechooser.FileFilter;
import javax.swing.filechooser.FileNameExtensionFilter;

//Lib BD elasticsearch
import org.elasticsearch.action.admin.indices.exists.indices.IndicesExistsResponse;
import org.elasticsearch.action.admin.cluster.health.ClusterHealthResponse;
import org.elasticsearch.action.index.IndexRequest;
import org.elasticsearch.action.index.IndexResponse;
import org.elasticsearch.action.search.SearchResponse;
import org.elasticsearch.action.search.SearchType;
import org.elasticsearch.client.Client;
import org.elasticsearch.common.settings.Settings;
import org.elasticsearch.node.Node;
import org.elasticsearch.node.NodeBuilder;

// Constantes para referir al nombre del indice y el tipo
static String INDEX_NAME = "canciones";
static String DOC_TYPE = "cancion";

String dir=""; // Directorio de la cancion sleccionada
float vol = 1;
PImage pl, pa, stp, va, vb, a;
boolean slct, s = false;
int Hp, Lp, Bp,bands=512;

ControlP5 cp5, btn, sldr;
ScrollableList list;

Minim minim;
AudioPlayer song;
AudioMetaData meta;
HighPassSP highpass;
LowPassSP lowpass;
BandPass bandpass;

Client client;
Node node;

void setup() {
  
  
  //Iconos botones
  pl = loadImage("play.png");
  pa = loadImage("pause.png");
  stp = loadImage("stop.png"); 
  va = loadImage("va.png");
  vb = loadImage("vb.png");
  a = loadImage("a.png");
  
  //Botones interfaz
  btn = new ControlP5(this);
  btn.addButton("Play").setValue(0).setSize(10, 10).setImage(pl).setPosition(30, 480);
  btn=new ControlP5(this);
  btn.addButton("Stop").setValue(0).setSize(10, 10).setImage(stp).setPosition(87, 480);
  btn=new ControlP5(this);
  btn.addButton("Pause").setValue(0).setSize(10, 10).setImage(pa).setPosition(155, 480);
  btn=new ControlP5(this);
  btn.addButton("Subir").setValue(0).setSize(10, 10).setImage(va).setPosition(217, 480);
  btn=new ControlP5(this);
  btn.addButton("Bajar").setValue(0).setSize(10, 10).setImage(vb).setPosition(280, 480);

  //Sliders ecualizador
  sldr=new ControlP5(this);
  sldr.addSlider("Hp").setPosition(105, 250).setSize(10, 50).setRange(1000, 14000).setValue(1000).setNumberOfTickMarks(10);
  sldr.addSlider("Lp").setPosition(155, 250).setSize(10, 50).setRange(3000, 20000).setValue(3000).setNumberOfTickMarks(10);
  sldr.addSlider("Bp").setPosition(205, 250).setSize(10, 50).setRange(100, 1000).setValue(100).setNumberOfTickMarks(10);
  //sldr.getController("Hp").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(100);
  //sldr.getController("Lp").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(100);
  //sldr.getController("Bp").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(100);

  minim = new Minim(this);
  
  // |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||


  size(320, 568);
  cp5 = new ControlP5(this);

  // Configuracion basica para ElasticSearch en local
  Settings.Builder settings = Settings.settingsBuilder();
  // Esta carpeta se encontrara dentro de la carpeta del Processing
  settings.put("path.data", "esdata");
  settings.put("path.home", "/");
  settings.put("http.enabled", false);
  settings.put("index.number_of_replicas", 0);
  settings.put("index.number_of_shards", 1);

  // Inicializacion del nodo de ElasticSearch
  node = NodeBuilder.nodeBuilder()
    .settings(settings)
    .clusterName("mycluster")
    .data(true)
    .local(true)
    .node();

  // Instancia de cliente de conexion al nodo de ElasticSearch
  client = node.client();

  // Esperamos a que el nodo este correctamente inicializado
  ClusterHealthResponse r = client.admin().cluster().prepareHealth().setWaitForGreenStatus().get();
  println(r);

  // Revisamos que nuestro indice (base de datos) exista
  IndicesExistsResponse ier = client.admin().indices().prepareExists(INDEX_NAME).get();
  if (!ier.isExists()) {
    // En caso contrario, se crea el indice
    client.admin().indices().prepareCreate(INDEX_NAME).get();
  }

  // Agregamos a la vista un boton de importacion de archivos
  cp5.addButton("importFiles")
    .setPosition(155, height  -20)
    .setSize(100, 10)
    .setImage(a);

  // Agregamos a la vista una lista scrollable que mostrara las canciones
  list = cp5.addScrollableList("playlist")
    .setPosition(0, 0)
    .setSize(500, 100)
    .setBarHeight(20)
    .setItemHeight(20)
    .setType(ScrollableList.LIST);
    //.setColorBackground(210);
    //.setColorForeground(190);

  // Cargamos los archivos de la base de datos
  loadFiles();
}

void draw() {
  background(180);
  noStroke();
  fill(200);
  rect(0, 360, width, height - 360);
  
  if (slct) {
    //fill(190);
    //noStroke();
    //fill(0);
    
    PFont helvetica;
    helvetica = createFont("Helvetica.dfont", 10);
    textFont(helvetica);
    fill(0);
    textSize(18);
    text("" + meta.title(), 30, 420);
    textSize(13);
    text("" + meta.author(), 30 , 450);
    
    highpass.setFreq(Hp);
    lowpass.setFreq(Lp);
    bandpass.setFreq(Bp);
    
 
    for ( int i = 0; i < song.bufferSize() - 1; i++ )
    {
      float x1 = map(i, 0, song.bufferSize(), 0, width);
      float x2 = map(i+1, 0, song.bufferSize(), 0, width);
      line(x1, height/6 - song.left.get(i)*50, x2, height/6 - song.left.get(i+1)*50);
      line(x1, 3*height/6 - song.right.get(i)*50, x2, 3*height/6 - song.right.get(i+1)*50);
    }
  }
}

void importFiles() {
  // Selector de archivos
  JFileChooser jfc = new JFileChooser();
  // Agregamos filtro para seleccionar solo archivos .mp3
  jfc.setFileFilter(new FileNameExtensionFilter("MP3 File", "mp3"));
  // Se permite seleccionar multiples archivos a la vez
  jfc.setMultiSelectionEnabled(true);
  // Abre el dialogo de seleccion
  jfc.showOpenDialog(null);

  // Iteramos los archivos seleccionados
  for (File f : jfc.getSelectedFiles()) {
    // Si el archivo ya existe en el indice, se ignora
    GetResponse response = client.prepareGet(INDEX_NAME, DOC_TYPE, f.getAbsolutePath()).setRefresh(true).execute().actionGet();
    if (response.isExists()) {
      continue;
    }

    // Cargamos el archivo en la libreria minim para extrar los metadatos
    Minim minim = new Minim(this);
    AudioPlayer song = minim.loadFile(f.getAbsolutePath());
    AudioMetaData meta = song.getMetaData();

    // Almacenamos los metadatos en un hashmap
    Map<String, Object> doc = new HashMap<String, Object>();
    doc.put("author", meta.author());
    doc.put("title", meta.title());
    doc.put("path", f.getAbsolutePath());

    try {
      // Le decimos a ElasticSearch que guarde e indexe el objeto
      client.prepareIndex(INDEX_NAME, DOC_TYPE, f.getAbsolutePath())
        .setSource(doc)
        .execute()
        .actionGet();

      // Agregamos el archivo a la lista
      addItem(doc);
    } 
    catch(Exception e) {
      e.printStackTrace();
    }
  }
}

void archivo() {
 if (s) {
   song = minim.loadFile(dir, 1024);
   meta = song.getMetaData();
   
   highpass = new HighPassSP(300, song.sampleRate());
   song.addEffect(highpass);
   lowpass = new LowPassSP(300, song.sampleRate());
   song.addEffect(lowpass);
   bandpass = new BandPass(300, 300, song.sampleRate());
   song.addEffect(bandpass);
   
   highpass.setFreq(Hp);
   lowpass.setFreq(Lp);
   bandpass.setFreq(Bp);
   slct=true;
 }
}

// Al hacer click en algun elemento de la lista, se ejecuta este metodo
void playlist(int n) {
  //println(list.getItem(n));
  Map<String, Object> v =(Map<String, Object>)list.getItem(n).get("value");
  println (v.get("path"));
  dir =(v.get("path").toString());
  s=true;
  archivo();
}

void loadFiles() {
  try {
    // Buscamos todos los documentos en el indice
    SearchResponse response = client.prepareSearch(INDEX_NAME).execute().actionGet();

    // Se itera los resultados
    for (SearchHit hit : response.getHits().getHits()) {
      // Cada resultado lo agregamos a la lista
      addItem(hit.getSource());
    }
  } 
  catch(Exception e) {
    e.printStackTrace();
  }
}

public void Sele() {
  slct=false;
  selectInput("selecciona un archivo: ", "archivo seleccionado");
}
public void Play() {
  song.play();
  println("Play");
}
public void Stop() {
  song.pause();
  song.rewind();
  println("Stop");
  slct=false;
  s=false;
}
public void Pause() {
  song.pause();
  println("Pause");
}
public void Subir() {
  vol = vol + 2;
  song.setGain(vol);
  println("Subir");
}
public void Bajar() {
  vol = vol - 2;
  song.setGain(vol);
  println("Bajar");
}

// Metodo auxiliar para no repetir codigo
void addItem(Map<String, Object> doc) {
  // Se agrega a la lista. El primer argumento es el texto a desplegar en la lista, el segundo es el objeto que queremos que almacene
  list.addItem(doc.get("author") + " - " + doc.get("title"), doc);
}