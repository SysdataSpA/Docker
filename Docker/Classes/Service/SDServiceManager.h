#import <Foundation/Foundation.h>
#import "SDServiceGeneric.h"
#import <AFNetworking/AFNetworking.h>

typedef void (^ ServiceCompletionSuccessHandler)(id<SDServiceGenericResponseProtocol> _Nullable response);
typedef void (^ ServiceCompletionFailureHandler)(id<SDServiceGenericErrorProtocol> _Nullable error);
typedef void (^ ServiceDownloadProgressHandler)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead);
typedef void (^ ServiceUploadProgressHandler)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite);
typedef NSCachedURLResponse* _Nullable (^ ServiceCachingBlock)(NSURLConnection* _Nullable connection, NSCachedURLResponse* _Nullable cachedResponse);

typedef NS_ENUM (NSInteger, SDServiceOperationType)
{
    kSDServiceOperationTypeInvalid = -1
};

@protocol SDServiceManagerDelegate;
/**
 *  Wrapper class for a single call of SDServiceGeneric.
 */
@interface SDServiceCallInfo : NSObject

- (instancetype _Nonnull) initWithService:(SDServiceGeneric* _Nonnull)service request:(id<SDServiceGenericRequestProtocol> _Nonnull)request;

@property (readonly, nonatomic, strong) SDServiceGeneric* _Nonnull service;
@property (readonly, nonatomic, strong) id<SDServiceGenericRequestProtocol> _Nonnull request;
@property (nonatomic, assign) SDServiceOperationType type;
@property (nonatomic, weak) id <SDServiceManagerDelegate> _Nullable delegate;
@property (nonatomic, assign) SEL _Nullable actionSelector;

@property (nonatomic, assign) BOOL isProcessing;
@property (nonatomic, assign) int numAutomaticRetry;

@property (nonatomic, strong) ServiceCompletionSuccessHandler _Nullable completionSuccess;
@property (nonatomic, strong) ServiceCompletionFailureHandler _Nullable completionFailure;
@property (nonatomic, strong) ServiceDownloadProgressHandler _Nullable downloadProgressHandler;
@property (nonatomic, strong) ServiceUploadProgressHandler _Nullable uploadProgressHandler;
@property (nonatomic, strong) ServiceCachingBlock _Nullable cachingBlock;

@end

@protocol SDServiceManagerDelegate <NSObject>
@optional
/**
 *  Asks to delegate if can start operation for the service.
 *
 *  @param operation type of service
 *
 *  @return YES if the service could start, NO if service shouldn't start.
 */
- (BOOL) shouldStartServiceOperation:(SDServiceOperationType)operation;  // called before operation process starts (default YES, if not implemented)

/**
 *  Returns to delegate the total number of downloaded bytes.
 *
 *  @param totalBytesRead           Total bytes downloaded.
 *  @param totalBytesExpectedToRead Total bytes expected.
 */
- (void) didDownloadBytes:(long long)totalBytesRead onTotalExpected:(long long)totalBytesExpectedToRead;

/**
 *  Returns to delegate the total number of uploaded bytes.
 *
 *  @param totalBytesWritten         Total bytes uploaded.
 *  @param totalBytesExpectedToWrite Total bytes expected.
 */
- (void) didUploadBytes:(long long)totalBytesWritten onTotalExpected:(long long)totalBytesExpectedToWrite;

@required
/**
 *  Informs delegate that service did start.
 *
 *  @param operation type of service
 */
- (void) didStartServiceOperation:(SDServiceOperationType)operation;

/**
 *  Informs delegate that service did end.
 *
 *  @param operation type of service
 *  @param request   request of the service
 *  @param result    response of the service. Value nil if failure occured.
 *  @param error     response in case of failure. Value nil if operation did end with success.
 */
- (void) didEndServiceOperation:(SDServiceOperationType)operation withRequest:(id<SDServiceGenericRequestProtocol> _Nonnull)request result:(id<SDServiceGenericResponseProtocol> _Nullable)result error:(id<SDServiceGenericErrorProtocol> _Nullable)error; // called when Service operation process ends
@end

/**
 *  Questa classe deve essere estesa e mai utilizzata direttamente.
 */

#ifdef SD_LOGGER_AVAILABLE
@interface SDServiceManager : NSObject <SDLoggerModuleProtocol>
#else
@interface SDServiceManager : NSObject
#endif

+ (instancetype _Nonnull) sharedServiceManager;

/**
 *  Il Request Operation Manager di default.
 */
@property(nonatomic, strong) AFHTTPRequestOperationManager* _Nullable defaultRequestOperationManager;

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
@property (nonatomic, strong, readonly) NSMutableArray<SDServiceCallInfo*>* _Nullable servicesQueue;

/**
 *  Mappa dei servizi pending divisi per delegate. Key: hash del delegate, Value: array di SDServiceGeneric.
 */
@property (nonatomic, strong, readonly) NSMutableDictionary<NSNumber*, NSMutableArray<AFHTTPRequestOperation*>*>* _Nullable serviceInvocationDictionary;

/**
 *  Questo metodo viene chiamato al termine di tutte le operazioni del servizio (chiamata e mapping). L'implementazione di default non fa nulla.
 *
 *  N.B.: chiamare il super nelle estensioni.
 *
 *  @param serviceInfo Il servizio completato con successo.
 */
- (void) handleSuccessForServiceInfo:(SDServiceCallInfo* _Nullable)serviceInfo withResponse:(id<SDServiceGenericResponseProtocol> _Nullable)response;
- (void) handleSuccessForServiceInfo:(SDServiceCallInfo* _Nullable)serviceInfo __attribute__((deprecated("Method has been deprecated, please use handleSuccessForServiceInfo:withResponse: instead")));

/**
 *  Questo metodo viene chiamato al termine di tutte le operazioni del servizio (chiamata e mapping). L'implementazione di default non fa nulla.
 *
 *  N.B.: chiamare il super nelle estensioni.
 *
 *  @param serviceInfo Il servizio completato con errore.
 */
- (void) handleFailureForServiceInfo:(SDServiceCallInfo* _Nullable)serviceInfo withError:(id<SDServiceGenericErrorProtocol> _Nullable)serviceError;
- (void) handleFailureForServiceInfo:(SDServiceCallInfo*_Nullable )serviceInfo __attribute__((deprecated("Method has been deprecated, please use handleFailureForServiceInfo:withError: instead")));


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
- (void) performAutomaticRetry:(SDServiceCallInfo* _Nullable)serviceInfo;

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
- (BOOL) shouldCatchFailureForMissingResponseInServiceInfo:(SDServiceCallInfo* _Nullable)serviceInfo;

/**
 *  Versione alternativa a quella sopra che passa anche l'errore ottenuto
 */
- (BOOL) shouldCatchFailureForMissingResponseInServiceInfo:(SDServiceCallInfo* _Nullable)serviceInfo error:(NSError* _Nullable)error;

/**
 *  Cancella tutte le operazioni ancora in coda associate al servizio passato.
 *
 *  @param service Il servizio di cui si vuole cancellare tutte le operazioni pendenti.
 */
- (void) cancelAllOperationsForService:(SDServiceGeneric* _Nullable)service;

/**
 *  Cancella tutte le operazioni pendenti che hanno come delegate l'oggetto passato.
 *
 *  @param delegate Il delegate associato alle operazioni che si desidera cancellare.
 */
- (void) cancelAllOperationsForDelegate:(id <SDServiceManagerDelegate> _Nullable )delegate;

/**
 *  Restituisce il numero di operazioni ancora pendenti associate al delegate passato
 *
 *  @param delegate Il delegato di cui si desidera conoscere il numero di operazioni ancora pendenti.
 *
 *  @return Il numero di operazioni.
 */
- (NSUInteger) numberOfPendingOperationsForDelegate:(id <SDServiceManagerDelegate> _Nullable)delegate;

/**
 *  Controlla se ci sono operazioni pendenti associate al delegate passato.
 *
 *  @param delegate Il delegate di cui si desidera sapere se ci sono operazioni in coda.
 *
 *  @return YES se ci sono operazioni in coda che hanno come delegate l'oggetto passato, altrimenti NO.
 */
- (BOOL) hasPendingOperationsForDelegate:(id <SDServiceManagerDelegate> _Nullable)delegate;

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
- (void) callServiceWithServiceCallInfo:(SDServiceCallInfo* _Nonnull)serviceInfo;

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
- (void) callService:(SDServiceGeneric* _Nonnull)service
         withRequest:(id<SDServiceGenericRequestProtocol> _Nonnull)request
       operationType:(NSInteger)operationType
      responseAction:(SEL _Nullable)selector
   numAutomaticRetry:(int)numAutomaticRetry
            delegate:(id <SDServiceManagerDelegate> _Nullable)delegate
       downloadBlock:(ServiceDownloadProgressHandler _Nullable)downloadBlock
         uploadBlock:(ServiceUploadProgressHandler _Nullable)uploadBlock
   completionSuccess:(ServiceCompletionSuccessHandler _Nullable)completionSuccess
   completionFailure:(ServiceCompletionFailureHandler _Nullable)completionFailure
        cachingBlock:(ServiceCachingBlock _Nullable)cachingBlock;

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
- (void) callService:(SDServiceGeneric* _Nonnull)service withRequest:(id<SDServiceGenericRequestProtocol> _Nonnull)request operationType:(NSInteger)operationType delegate:(id <SDServiceManagerDelegate> _Nullable)delegate completionSuccess:(ServiceCompletionSuccessHandler _Nullable)completionSuccess completionFailure:(ServiceCompletionFailureHandler _Nullable)completionFailure;

@end
