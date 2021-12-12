//
//  SignInReactor.swift
//  Archive
//
//  Created by TTOzzi on 2021/10/02.
//

import ReactorKit
import RxSwift
import RxRelay
import RxFlow

final class SignInReactor: Reactor, Stepper {
    
    enum Action {
        case idInput(text: String)
        case passwordInput(text: String)
        case signIn
        case signUp
    }
    
    enum Mutation {
        case setID(String)
        case setPassword(String)
        case setValidation(Bool)
        case setIsLoading(Bool)
    }
    
    struct State {
        var id: String = ""
        var password: String = ""
        var isEnableSignIn: Bool = false
        var isLoading: Bool = false
    }
    
    let initialState = State()
    let steps = PublishRelay<Step>()
    private let validator: SignInValidator
    var error: PublishSubject<String>
    
    init(validator: SignInValidator) {
        self.validator = validator
        self.error = .init()
    }
    
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case let .idInput(id):
            let isValid = validator.isEnableSignIn(id: id, password: currentState.password)
            return .from([.setID(id),
                          .setValidation(isValid)])
            
        case let .passwordInput(password):
            let isValid = validator.isEnableSignIn(id: currentState.id, password: password)
            return .from([.setPassword(password),
                          .setValidation(isValid)])
            
        case .signIn:
            return Observable.concat([
                Observable.just(.setIsLoading(true)),
                self.loginEmail(eMail: self.currentState.id, password: self.currentState.password).map { [weak self] result in
                    switch result {
                    case .success(let response):
                        guard let token: String = response["Authorization"] else {
                            self?.error.onNext("[오류] 토큰이 존재하지 않습니다.")
                            return .setIsLoading(false)
                        }
                        UserDefaultManager.shared.setLoginToken(token)
                        self?.steps.accept(ArchiveStep.userIsSignedIn)
                    case .failure(let err):
                        print("err: \(err)")
                        self?.error.onNext("로그인 정보가 정확하지 않습니다.")
                    }
                    return .setIsLoading(false)
                }
            ])
            
        case .signUp:
            steps.accept(ArchiveStep.termsAgreementIsRequired)
            return .empty()
        }
    }
    
    
    
//        provider.request(.loginEmail(param), completion: { [weak self] response in
//            switch response {
//            case .success(let response):

//            case .failure(let err):
//                print("err: \(err.localizedDescription)")
//                self?.error.onNext("로그인 정보가 정확하지 않습니다.")
//            }
//        })
    
    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case let .setID(id):
            newState.id = id
            
        case let .setPassword(password):
            newState.password = password
            
        case let.setValidation(isEnableSignIn):
            newState.isEnableSignIn = isEnableSignIn
        case let .setIsLoading(isLoading):
            newState.isLoading = isLoading
        }
        return newState
    }
    
    private func loginEmail(eMail: String, password: String) -> Observable<Result<HTTPHeaders, Error>> {
        let provider = ArchiveProvider.shared.provider
        let param = LoginEmailParam(email: eMail, password: password)
        return provider.rx.request(.loginEmail(param), callbackQueue: DispatchQueue.global())
            .asObservable()
            .map { result in
                if let headers = result.response?.headers {
                    return .success(headers)
                } else {
                    return .failure(NSError())
                }
            }
            .catch { err in
                .just(.failure(err))
            }
    }
}

struct LoginEmailParam: Encodable {
    var email: String
    var password: String
}
