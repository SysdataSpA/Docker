#import <Foundation/Foundation.h>
#import "SDServiceGeneric.h"
#import <AFNetworking/AFNetworking.h>

typedef void (^ ServiceCompletionSuccessHandler)(id<SDServiceGenericResponseProtocol> response);
typedef void (^ ServiceCompletionFailureHandler)(id<SDServiceGenericErrorProtocol> error);
typedef void (^ ServiceDownloadProgressHandler)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead);
typedef void (^ ServiceUploadProgressHandler)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite);
typedef NSCachedURLResponse* (^ ServiceCachingBlock)(NSURLConnection* connection, NSCachedURLResponse* cachedResponse);

typedef NS_ENUM (NSInteger, SDServiceOperationType)
{
    kSDServiceOperationTypeInvalid = -1
};

@protocol SDServiceManagerDelegate;
/**
 *  Classe wrapper di una singola chiamata per un SDServiceGeneric.
 */
@interface SDServiceCallInfo : NSObject

- (instancetype) initWithService:(SDServiceGeneric*)service request:(id<SDServiceGenericRequestProtocol>)request;

@property (readonly, nonatomic, strong) SDServiceGeneric* service;
@property (readonly, nonatomic, strong) id<SDServiceGenericRequestProtocol> request;
@property (nonatomic, assign) SDServiceOperationType type;
@property (nonatomic, weak) id <SDServiceManagerDelegate> delegate;
@property (nonatomic, assign) SEL actionSelector;

@property (nonatomic, assign) BOOL isProcessing;
@property (nonatomic, assign) int numAutomaticRetry;

@property (nonatomic, strong) ServiceCompletionSuccessHandler completionSuccess;
@property (nonatomic, strong) ServiceCompletionFailureHandler completionFailure;
@property (nonatomic, strong) ServiceDownloadProgressHandler downloadProgressHandler;
@property (nonatomic, strong) ServiceUploadProgressHandler uploadProgressHandler;
@property (nonatomic, strong) ServiceCachingBlock cachingBlock;

@end

@protocol SDServiceManagerDelegate <NSObject>
@optional
/**
 *  Chiede al delegate se può iniziare l'operazione sul servizio del tipo passato.
 *
 *  @param operation Il tipo di servizio
 *
 *  @return YES se il servizio può essere eseguito, NO se deve essere bloccato.
 */
- (BOOL) shouldStartServiceOperation:(SDServiceOperationType)operation;  // called before operation process starts (default YES, if not implemented)

/**
 *  Riporta al delegate il totale di bytes scaricati.
 *
 *  @param totalBytesRead           Totale di bytes scaricati.
 *  @param totalBytesExpectedToRead Totale di bytes stimati.
 */
- (void) didDownloadBytes:(long long)totalBytesRead onTotalExpected:(long long)totalBytesExpectedToRead;

/**
 *  Riporta al delegate il totale di bytes inviati.
 *
 *  @param totalBytesWritten         Totale di bytes inviati.
 *  @param totalBytesExpectedToWrite Totale di bytes stimati.
 */
- (void) didUploadBytes:(long long)totalBytesWritten onTotalExpected:(long long)totalBytesExpectedToWrite;

@required
/**
 *  Informa il delegate che un servizio del tipo passato ha iniziato la propria operazione.
 *
 *  @param operation Il tipo di servizio
 */
- (void) didStartServiceOperation:(SDServiceOperationType)operation;

/**
 *  Informa il delegate che un servizio del tipo passato ha completato la propria operazione.
 *
 *  @param operation Il tipo di servizio
 *  @param request   La request legata al servizio
 *  @param result    La response del servizio. Il valore è nil se l'operazione è fallita.
 *  @param error     La response in caso di errore. Il valore è nil se l'operazione ha avuto successo.
 */
- (void) didEndServiceOperation:(SDServiceOperationType)operation withRequest:(id<SDServiceGenericRequestProtocol>)request result:(id<SDServiceGenericResponseProtocol>)result error:(id<SDServiceGenericErrorProtocol>)error; // called when Service operation process ends
@end

/**
 *  Questa classe deve essere estesa e mai utilizzata direttamente.
 */

#ifdef SD_LOGGER_AVAILABLE
@interface SDServiceManager : NSObject <SDLoggerModuleProtocol>
#else
@interface SDServiceManager : NSObject
#endif

+ (instancetype) sharedServiceManager;

/**
 *  Il Request Operation Manager di default.
 */
@property(nonatomic, strong) AFHTTPRequestOperationManager* defaultRequestOperationManager;

/**
 *  Tempo di attesa in secondi tra un fallimento e il successivo retry di un servizio ripetibile. Di default è 3 secondi.
 */
@property (nonatomic, assign) NSTimeInterval timeBeforeRetry;

/**
 *  Flag che indica se le response dei servizi devono essere recuperate da file in locale. Default è NO.
 *
 *  @discussion Settare a YES per far sì che tutti i servizi tentino di recuperare le response da file.
 *  Se si vuole che solo alcuni servizi specifici usino la demo mode, allora settare il flag dei relativi servizi.
 */
@property (nonatomic, assign) BOOL useDemoMode;


/**
 *  Coda dei servizi non ancora eseguiti.
 */
@property (nonatomic, strong, readonly) NSMutableArray* servicesQueue;

/**
 *  Mappa dei servizi pending divisi per delegate. Key: hash del delegate, Value: array di SDServiceGeneric.
 */
@property (nonatomic, strong, readonly) NSMutableDictionary* serviceInvocationDictionary;

/**
 *  Questo metodo viene chiamato al termine di tutte le operazioni del servizio (chiamata e mapping). L'implementazione di default non fa nulla.
 *
 *  N.B.: chiamare il super nelle estensioni.
 *
 *  @param serviceInfo Il servizio completato con successo.
 */
- (void) handleSuccessForServiceInfo:(SDServiceCallInfo*)serviceInfo withResponse:(id<SDServiceGenericResponseProtocol>)response;
- (void) handleSuccessForServiceInfo:(SDServiceCallInfo*)serviceInfo __attribute__((deprecated("Method has been deprecated, please use handleSuccessForServiceInfo:withResponse: instead")));

/**
 *  Questo metodo viene chiamato al termine di tutte le operazioni del servizio (chiamata e mapping). L'implementazione di default non fa nulla.
 *
 *  N.B.: chiamare il super nelle estensioni.
 *
 *  @param serviceInfo Il servizio completato con errore.
 */
- (void) handleFailureForServiceInfo:(SDServiceCallInfo*)serviceInfo withError:(id<SDServiceGenericErrorProtocol>)serviceError;
- (void) handleFailureForServiceInfo:(SDServiceCallInfo*)serviceInfo __attribute__((deprecated("Method has been deprecated, please use handleFailureForServiceInfo:withError: instead")));


/**
 *  Questo metodo viene richiamato quando non ci sono più operazioni pendenti, sono state rimosse tutte dalla coda. Un'operazione viene rimossa SOLO se
 *     - ha successo
 *     - se viene cancellata
 *     - se ha un errore con response (un 400)
 *     - se ha errore di connessione (non ha response) e shouldCatchFailureForMissingResponseInServiceInfo ritorna NO
 */
- (void) didCompleteAllServices;


/**
 *  Ripete immediatamente il servizio passato e decrementa il relativo numero di tentativi automatici
 *
 *  @param serviceInfo Il servizio da ripetere
 */
- (void) performAutomaticRetry:(SDServiceCallInfo*)serviceInfo;

/**
 *  Ripete i servizi falliti ancora in coda.
 */
- (void) repeatFailedServices;

/**
 *  Se il servizio prevede l'automatic retry, di default il metodo la esegue e restituisce NO. Se invece il servizio non prevede l'automatic retry, di default restituisce YES.
 *
 *  YES indica che il fallimento viene propagato al delegato e chiama il failure block. NO indica che l'errore viene soppresso.
 *
 *  Sovrascrivere questo metodo se si intende gestire in maniera differenziata per servizio il fallimento senza response.
 *
 *  @param serviceInfo Il servizio che è fallito senza response da parte del server.
 *
 *  @return Un flag che indica se il fallimento senza response deve essere propagato al delegato e chiamare il failure block.
 */
- (BOOL) shouldCatchFailureForMissingResponseInServiceInfo:(SDServiceCallInfo*)serviceInfo;

/**
 *  Versione alternativa a quella sopra che passa anche l'errore ottenuto
 */
- (BOOL) shouldCatchFailureForMissingResponseInServiceInfo:(SDServiceCallInfo*)serviceInfo error:(NSError*)error;

/**
 *  Cancella tutte le operazioni ancora in coda associate al servizio passato.
 *
 *  @param service Il servizio di cui si vuole cancellare tutte le operazioni pendenti.
 */
- (void) cancelAllOperationsForService:(SDServiceGeneric*)service;

/**
 *  Cancella tutte le operazioni pendenti che hanno come delegate l'oggetto passato.
 *
 *  @param delegate Il delegate associato alle operazioni che si desidera cancellare.
 */
- (void) cancelAllOperationsForDelegate:(id <SDServiceManagerDelegate> )delegate;

/**
 *  Restituisce il numero di operazioni ancora pendenti associate al delegate passato
 *
 *  @param delegate Il delegato di cui si desidera conoscere il numero di operazioni ancora pendenti.
 *
 *  @return Il numero di operazioni.
 */
- (NSUInteger) numberOfPendingOperationsForDelegate:(id <SDServiceManagerDelegate> )delegate;

/**
 *  Controlla se ci sono operazioni pendenti associate al delegate passato.
 *
 *  @param delegate Il delegate di cui si desidera sapere se ci sono operazioni in coda.
 *
 *  @return YES se ci sono operazioni in coda che hanno come delegate l'oggetto passato, altrimenti NO.
 */
- (BOOL) hasPendingOperationsForDelegate:(id <SDServiceManagerDelegate> )delegate;

/**
 *  Restituisce il numero di operazioni ancora pendenti
 *
 *  @return Il numero di operazioni.
 */
- (NSUInteger) numberOfPendingOperations;

/**
 *  Controlla se ci sono operazioni pendenti
 *
 *  @return YES se ci sono operazioni in coda, altrimenti NO.
 */
- (BOOL) hasPendingOperations;

/**
 *  Mette in coda l'operazione per chiamare il servizio con tutti i dettagli indicati nell'oggetto info.
 *
 *  @param serviceInfo Oggetto che contiene tutte le informazioni relative al servizio da chiamare.
 */
- (void) callServiceWithServiceCallInfo:(SDServiceCallInfo*)serviceInfo;

/**
 *  Mette in coda l'operazione per chiamare il servizio dato con tutti i dettagli indicati.
 *
 *  @param service           Il servizio da mettere in coda.
 *  @param request           L'oggetto request che contiene i parametri per la chiamata.
 *  @param operationType     Valore intero che identifica il tipo di servizio.
 *  @param selector          Il selettore del servizio da chiamare al termine delle operazioni. Opzionale.
 *  @param numAutomaticRetry Il massimo di tentativi da effettuare in caso di errore nel servizio. 0 indica che non verranno effettuati nuovi tentativi in caso di errore.
 *  @param delegate          Oggetto che implementa il protocollo SDServiceManagerDelegate per essere informato sul ciclo di vita dell'operazione. Opzionale.
 *  @param downloadBlock     Blocco eseguito alla ricezione di ogni pacchetto. Opzionale.
 *  @param uploadBlock       Blocco eseguito all'invio di ogni pacchetto. Opzionale.
 *  @param completionSuccess Blocco eseguito in caso di successo del servizio. Opzionale.
 *  @param completionFailure Blocco eseguito in caso di errore del servizio. Opzionale.
 *  @param cachingBlock      Blocco eseguito in caso di successo del servizio prima di cachare la response nella NSURLCache. Opzionale.
 */
- (void) callService:(SDServiceGeneric*)service
         withRequest:(id<SDServiceGenericRequestProtocol>)request
       operationType:(NSInteger)operationType
      responseAction:(SEL)selector
   numAutomaticRetry:(int)numAutomaticRetry
            delegate:(id <SDServiceManagerDelegate> )delegate
       downloadBlock:(ServiceDownloadProgressHandler)downloadBlock
         uploadBlock:(ServiceUploadProgressHandler)uploadBlock
   completionSuccess:(ServiceCompletionSuccessHandler)completionSuccess
   completionFailure:(ServiceCompletionFailureHandler)completionFailure
        cachingBlock:(ServiceCachingBlock)cachingBlock;

/**
 *  Mette in coda l'operazione per chiamare il servizio dato. Il servizio non prevede nuovi tentativi in caso di errore.
 *
 *  @param service           Il servizio da mettere in coda.
 *  @param request           L'oggetto request che contiene i parametri per la chiamata.
 *  @param operationType     Valore intero che identifica il tipo di servizio.
 *  @param delegate          Oggetto che implementa il protocollo SDServiceManagerDelegate per essere informato sul ciclo di vita dell'operazione. Opzionale.
 *  @param completionSuccess Blocco eseguito in caso di successo del servizio. Opzionale.
 *  @param completionFailure Blocco eseguito in caso di errore del servizio. Opzionale.
 */
- (void) callService:(SDServiceGeneric*)service withRequest:(id<SDServiceGenericRequestProtocol>)request operationType:(NSInteger)operationType delegate:(id <SDServiceManagerDelegate> )delegate completionSuccess:(ServiceCompletionSuccessHandler)completionSuccess completionFailure:(ServiceCompletionFailureHandler)completionFailure;

@end
