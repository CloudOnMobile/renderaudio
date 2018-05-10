
/*: Render offline
 
 ### Contents
 
 1. Definir y asociar los Audios -> AVAudioFile
 2. Setup del Engine
 3. Nodos y efectos
 4. Reproducir audio
 5. Crear fichero de salida para el nuevo audio
 6. Setup del modo offline del Engine
 7. Render loop y setup del buffer para el render
 8. Play del nuevo audio
 
 */


import AVFoundation
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

let sourceFileBase: AVAudioFile
let sourceFileVocal: AVAudioFile
let formatMusic : AVAudioFormat
let formatVocal: AVAudioFormat

do {
    let sourceUrlFileBase = Bundle.main.url(forResource: "HipHop375", withExtension: "wav")!
    sourceFileBase = try AVAudioFile(forReading: sourceUrlFileBase)
    
    let sourceUrlFileVocal = Bundle.main.url(forResource: "106_Publik-Enemi-yes", withExtension:"wav")!
    sourceFileVocal = try AVAudioFile(forReading: sourceUrlFileVocal)
    formatMusic = sourceFileBase.processingFormat
    formatVocal = sourceFileVocal.processingFormat
} catch {
    fatalError("error: 💩💩💩💩 - \(error)")
}
/*:
 ### Setup del Engine:
    AVAudioEngine será la clase encargada de hacer el render del audio, en realidad el engine hace de Hub permitiendo conectar varios nodos como entrada y una sola salida.
 
    También crearemos una instancia de AVAudioPlayerNode, siguiendo la relación Audio -> PlayerNode.
 
    Cada uno de los PlayerNode que creemos deberemos attacharlos al engine y déspues conectarlos a la salida de "mezcla" del engine.
 */
let engine = AVAudioEngine()
var player = AVAudioPlayerNode()
var vocal = AVAudioPlayerNode()

engine.attach(player)
engine.attach(vocal)
engine.connect(vocal, to: engine.mainMixerNode, format: formatVocal)
engine.connect(player, to: engine.mainMixerNode, format: formatMusic)


/*:
 
 ### Efectos
    Los efectos están basados en subclases de AVAudioUnitEffect, esta clase sirve para procesar audio usando internamente AudioUnit. Estos efectos corren en tiempo real
 
 */
// MARK: add effect ------ BASE
let reverb = AVAudioUnitReverb()
engine.attach(reverb)
reverb.loadFactoryPreset(.smallRoom)
reverb.wetDryMix = 70

/*:

 ## player -> reverb -> mainMixer -> output
 
 conectamos el effecto con el player siguendo esta secuencia
 
*/


engine.connect(player, to: reverb, format: formatMusic)
engine.connect(reverb, to: engine.mainMixerNode, format: formatMusic)

// MARK: add timepitch
let timePitch = AVAudioUnitTimePitch()
engine.attach(timePitch)
timePitch.pitch = 500
timePitch.rate = 1
/*:
 Repetimos los mismos pasos para la parte vocal
 ## player -> reverb -> mainMixer -> output
 conectamos el effecto con el player siguendo esta secuencia
 
 */


engine.connect(vocal, to: timePitch, format: formatVocal)
engine.connect(timePitch, to: engine.mainMixerNode, format: formatVocal)


vocal.scheduleFile(sourceFileVocal, at: nil, completionHandler: nil)
player.scheduleFile(sourceFileBase, at: nil, completionHandler: nil)
//do {
//    try engine.start()
//
//    player.play()
//    vocal.play()
//
//} catch {
//    fatalError("error: 😱😱😱😱 - \(error)")
//}

// MARK: RENDER
/*:
 - Creamos el fichero de salida para almacenar el audio renderizado
 */

var outputRender = AVAudioFile()
do {
    let docuPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    let outputUrl = URL(fileURLWithPath: docuPath + "/renderProcess.caf")
    outputRender = try AVAudioFile(forWriting: outputUrl, settings: sourceFileBase.fileFormat.settings)
} catch {
    fatalError("error: 😱😱😱😱 - \(error)")
}
/*:
 ### Setup del engine para establecer modo offline.
 
 - Desde este momento, toda señal de audio será procesada "offline", aunque veamos llamadas al método play de los distintos AVAudioPlayerNode, no escucharemos nada.
 
 - Otra dato importante, como queremos generar un fichero con la mezcla de varios sonidos y efectos, para renderizar y ser muy eficientes usaremos un buffer en memoria de tipo AVAudioPCMBuffer.
 - En el buffer procesaremos trozitos del audio, el tamaño estará definido por la variable maxNumberOfFrames
 
 - Déspues de poner el modo offline, solo tenemos que lanzar el engine y los distintos playernodes
 
 */
do {
    let maxNumberOfFrames: AVAudioFrameCount = 4096
    try engine.enableManualRenderingMode(.offline,
                                         format: formatMusic,
                                         maximumFrameCount: maxNumberOfFrames)
    try engine.start()
    player.play()
    vocal.play()


} catch let error {
    print("error: 😱😱😱😱 - \(error)")
}


// crear buffer para renderizar offline
var buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                              frameCapacity: engine.manualRenderingMaximumFrameCount)!


/*:
 ### RENDER LOOP

- Procesaremos la salida del engine cachito a cachito y si no tenemos error escribiremos en el AVAudioFile de salida que hemos creado antes
 
- Una vez terminado el render paramos los nodos y el engine.
 */


while engine.manualRenderingSampleTime < sourceFileBase.length {
    do {
        let framesToRender = min(buffer.frameCapacity,
                                 AVAudioFrameCount(sourceFileBase.length - engine.manualRenderingSampleTime))

        let status = try engine.renderOffline(framesToRender, to: buffer)
        switch status {
        case .success: try outputRender.write(from: buffer)
        case .error: fatalError("Zasca!!! fallo en renderloop")
        default: break
        }
    } catch {
        fatalError("Error")
    }
}
vocal.stop()
player.stop()
engine.stop()

print("fichero de entrada -> \(sourceFileBase.url)\n")
print("fichero de salida -> \(outputRender.url)\n")
print("Fin del render")

let newMixAF = try AVAudioFile(forReading: outputRender.url)
let playerMix = AVAudioPlayerNode()

engine.attach(playerMix)
engine.connect(playerMix, to: engine.mainMixerNode, format: newMixAF.processingFormat)
playerMix.scheduleFile(outputRender, at: nil, completionHandler: nil)
do {
    engine.disableManualRenderingMode()
    try engine.start()

    playerMix.play()


} catch {
    fatalError("error: 😱😱😱😱 - \(error)")
}

