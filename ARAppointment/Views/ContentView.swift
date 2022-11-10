//
//  ContentView.swift
//  ARAppointment
//
//  Created by burisowa on 2022/10/11.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    var body: some View {
        ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewControllerRepresentable {
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ARViewContainer>) -> ARViewController {
        let viewController = ARViewController()
        viewController.delegate = context.coordinator
        
        return viewController
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: UIViewControllerRepresentableContext<ARViewContainer>) {
    }
    
    func makeCoordinator() -> ARViewContainer.Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, ARViewControllerDelegate  {
        var parent: ARViewContainer

        init(_ viewContainer: ARViewContainer) {
            parent = viewContainer
        }
        
        func test(_ viewController: UIViewController) {
            print("gagagagaggagagagagagga")
        }
    }
}


protocol ARViewControllerDelegate: NSObjectProtocol {
    func test(_ viewController: UIViewController)
}


#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
