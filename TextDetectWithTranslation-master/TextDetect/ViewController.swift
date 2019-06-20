//
//  ViewController.swift
//  TextDetect
//
//  Created by Sayalee on 6/13/18.
//  Copyright © 2018 Assignment. All rights reserved.
//

import UIKit
import Firebase
import Speech

class ViewController: UIViewController, UINavigationControllerDelegate {

    @IBOutlet weak var detectedText: UILabel!
    @IBOutlet weak var inputText: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var languagePickerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var languagePicker: UIPickerView!
    @IBOutlet weak var languageSelectorButton: UIButton!
    @IBOutlet weak var translatedText: UILabel!

    @IBOutlet weak var startStopBtn: UIButton!
    let languages = ["Select Language", "Korean", "French", "Italian", "German", "Japanese"]
    let languageCodes = ["ko", "ko", "fr", "it", "de", "ja"]

    lazy var vision = Vision.vision()
    var textDetector: VisionTextDetector?
    var pickerVisible: Bool = false
    var targetCode = "ko"
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US")) //1
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    var lang: String = "en-US"

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLanguagePicker()
        startStopBtn.isEnabled = false  //2
        speechRecognizer?.delegate = self as? SFSpeechRecognizerDelegate  //3
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
        SFSpeechRecognizer.requestAuthorization { (authStatus) in  //4

            var isButtonEnabled = false

            switch authStatus {  //5
            case .authorized:
                isButtonEnabled = true

            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")

            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")

            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            }

            OperationQueue.main.addOperation() {
                self.startStopBtn.isEnabled = isButtonEnabled
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Configuration
    func configureLanguagePicker() {
        languagePicker.dataSource = self
        languagePicker.delegate = self
    }

    @IBAction func startStopAct(_ sender: Any) {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))

        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            startStopBtn.isEnabled = false
            startStopBtn.setTitle("Start", for: .normal)
        } else {
            startRecording()
            startStopBtn.setTitle("Stop", for: .normal)
        }
    }
    func startRecording() {

        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode

        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }

        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in

            var isFinal = false

            if result != nil {

                self.inputText.text = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal)!
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.startStopBtn.isEnabled = true
            }
        })

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }

    }

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            startStopBtn.isEnabled = true
        } else {
            startStopBtn.isEnabled = false
        }
    }

}

// MARK: - UIImagePickerControllerDelegate

extension ViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {

        dismiss(animated: true, completion: nil)

        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            fatalError("couldn't load image")
        }
        imageView.image = image

        detectText(image: image)
    }
}

// MARK :- UIPickerViewDelegate

extension ViewController: UIPickerViewDataSource, UIPickerViewDelegate {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return languages.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return languages[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        languageSelectorButton.setTitle(languages[row], for: .normal)
        targetCode = languageCodes[row]
    }
}

// MARK: - IBActions

extension ViewController {

    @IBAction func languageSelectorTapped(_ sender: Any) {

        if pickerVisible {
            languagePickerHeightConstraint.constant = 0
            pickerVisible = false
            translateText(detectedText: self.detectedText.text ?? "")
        } else {
            languagePickerHeightConstraint.constant = 150
            pickerVisible = true
        }

        UIView.animate(withDuration: 0.3) {
            self.view.layoutSubviews()
            self.view.updateConstraints()
        }
    }

    @IBAction func cameraButtonTapped(_ sender: Any) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera)  else {
            let alert = UIAlertController(title: "No camera", message: "This device does not support camera.", preferredStyle: .alert)
            let ok = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            alert.addAction(ok)
            self.present(alert, animated: true, completion: nil)
            return
        }

        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        self.present(picker, animated: true, completion: nil)
    }

    @IBAction func photosButtonTapped(_ sender: Any) {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary)  else {
            let alert = UIAlertController(title: "No photos", message: "This device does not support photos.", preferredStyle: .alert)
            let ok = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            alert.addAction(ok)
            self.present(alert, animated: true, completion: nil)
            return
        }

        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        self.present(picker, animated: true, completion: nil)
    }

}

// MARK: - Methods

extension ViewController {
    func detectText (image: UIImage) {

        textDetector = vision.textDetector()

        let visionImage = VisionImage(image: image)

        textDetector?.detect(in: visionImage) { (features, error) in
            guard error == nil, let features = features, !features.isEmpty else {
                return
            }

            debugPrint("Feature blocks in the image: \(features.count)")

            var detectedText = ""
            var inputText = ""
            for feature in features {
                let value = feature.text
                detectedText.append("\(value) ")
            }
            inputText = detectedText
            self.detectedText.text = detectedText
            self.inputText.text = detectedText
            //self.translateText(detectedText: inputText)
        }
    }
    @IBAction func TransBut(_ sender: Any) {

        self.translateText(detectedText: self.inputText.text!)
    }

    func translateText(detectedText: String) {

        guard !detectedText.isEmpty else {
            return
        }

        let task = try? GoogleTranslate.sharedInstance.translateTextTask(text: detectedText, targetLanguage: self.targetCode, completionHandler: { (translatedText: String?, error: Error?) in
            debugPrint(error?.localizedDescription)

            DispatchQueue.main.async {
                self.translatedText.text = translatedText
            }

        })
        task?.resume()
    }
}
