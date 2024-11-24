\version "2.24.1"

%% PSG event definitions

#(define (define-event! type properties)
  (set-object-property! type
    'music-description
    (cdr (assq 'description properties)))
  (set! properties (assoc-set! properties 'name type))
  (set! properties (assq-remove! properties 'description))
  (hashq-set! music-name-to-property-table type properties)
  (set! music-descriptions
    (sort (cons (cons type properties)
      music-descriptions)
      alist<?)))

#(define-event-class 'psg-pedal-or-lever-event 'span-event)
#(define-event-class 'psg-slow-pedal-or-lever-event 'span-event)

#(define-event!
  'PsgPedalOrLeverEvent
  '((description . "Engage or release PSG pedal or knee level.")
    (types . (post-event event pedal-event psg-pedal-or-lever-event))))

#(define-event!
  'PsgSlowPedalOrLeverEvent
  '((description . "Set the engagement or release of PSG pedal or knee lever to slow.")
    (types . (post-event event pedal-event psg-slow-pedal-or-lever-event))))

%% ID helpers

#(define (psg-id-to-string x)
  (if (string? x)
    (begin x)
    (if (symbol? x)
      (symbol->string x)
      (number->string x))))

#(define (psg-id-type? x)
  (if (string? x)
    (begin #t)
    (if (symbol? x)
      (begin #t)
      (number? x))))
     
%% Event creation

make-psg-pedal-or-lever-event =
#(define-music-function
  (id span-dir amount)
  (psg-id-type? number? rational?)
  (if (> amount 2)
    (begin
      (ly:warning "Pedal or lever event with amount greater than extended (2) - processing as extended")
      (set! amount 2)))
  (if (<= amount 0)
    (begin
      (ly:warning "Pedal or lever event with zero or negative amount - setting to 1")
      (set! amount 1)))
  (make-music 'PsgPedalOrLeverEvent 'span-direction span-dir 'psg-id (psg-id-to-string id) 'amount amount))

psgFractional =
#(define-music-function
  (id num denom)
  (psg-id-type? integer? integer?)
  (make-psg-pedal-or-lever-event id START (/ num denom)))

psgExt =
#(define-music-function
  (id)
  (psg-id-type?)
  (make-psg-pedal-or-lever-event id START 2))

psgOn =
#(define-music-function
  (id)
  (psg-id-type?)
  (make-psg-pedal-or-lever-event id START 1))

psgOff =
#(define-music-function
  (id)
  (psg-id-type?)
  (make-psg-pedal-or-lever-event id STOP 1))

psgSlow =
#(define-music-function
  (id)
  (psg-id-type?)
  (make-music 'PsgSlowPedalOrLeverEvent 'psg-id (psg-id-to-string id)))
  
%% Copedent checks & predicate - here we define correct or bad input for defining copedents

#(define (psg-check-strings strings)
  (if (null? strings)
    (begin #t)
    (if (and (list? strings) (ly:pitch? (car strings)))
      (psg-check-strings (cdr strings))
      (ly:error ("Strings must be expressed as a list of pitches - use \\stringTuning to create!")))))

#(define (psg-check-alterations alterations)
  (if (null? alterations)
    (begin #t)
    (if (and (list? alterations) (number? (car alterations)))
      (psg-check-alterations (cdr alterations))
      (ly:error ("String alterations must be expressed a list of numbers in semitones!")))))

#(define (psg-check-pedals-and-levers strings pedal-and-levers)
  (if (null? pedal-and-levers)
    (begin #t)
    (let 
      ((current-alterations (cadar pedal-and-levers))
       (extended-alterations (caddar pedal-and-levers)))
      (if (and (= (length current-alterations) (length strings)) (or (null? extended-alterations)(= (length extended-alterations) (length strings))))
        (and (psg-check-alterations current-alterations) (psg-check-alterations extended-alterations) (psg-check-pedals-and-levers strings (cdr pedal-and-levers)))
        (ly:error ("Number of string alterations in pedal or lever doesn't match the number of strings!"))))))

#(define (psg-copedent? copedent)
  (if (and (not (null? copedent)) (list? copedent))
    (let 
      ((strings (car copedent))
       (pedals-and-levers (cdr copedent)))
      (and (psg-check-strings strings) (psg-check-pedals-and-levers strings pedals-and-levers)))
    (begin #f)))

%% Context properties

#(set-object-property! 'psg-copedent 'translation-type? psg-copedent?)
#(set-object-property! 'psg-tab-in-space 'translation-type? boolean?)
#(set-object-property! 'psg-clef-style 'translation-type? symbol?)

%% User grob properties

#(set-object-property! 'bracket-height 'backend-type? number?)
#(set-object-property! 'psg-display-style 'backend-type? symbol?)
#(set-object-property! 'psg-restate-when-broken 'backend-type? boolean?)

%% internals

#(set-object-property! 'psg-id 'backend-type? string?)
#(set-object-property! 'psg-amount 'backend-type? number?)
#(set-object-property! 'psg-continue 'backend-type? boolean?)
#(set-object-property! 'psg-slow 'backend-type? list?)
#(set-object-property! 'psg-restate 'backend-type? boolean?)

%% Copedent definition functions

psg-define-pedal-or-lever-ext =
#(define-scheme-function
  (id alterations extended-alterations)
  (psg-id-type? list? list?)
  (list (psg-id-to-string id) (reverse alterations) (reverse extended-alterations)))

psg-define-pedal-or-lever =
#(define-scheme-function
  (id alterations)
  (psg-id-type? list?)
  (psg-define-pedal-or-lever-ext id alterations '()))

psg-define-copedent =
#(define-scheme-function
  (strings pedal-and-levers)
  (list? list?)
  (define copedent (append (list strings) pedal-and-levers))
  (if (psg-copedent? copedent)
    (begin copedent)
    (begin (ly:error ("Copedent is not correctly defined!")'(())))))
    
%% Utilities for accessing parts of a copedent

#(define (psg-copedent-strings copedent)
  (car copedent))
  
#(define (psg-copedent-pedals-and-levers copedent)
  (cdr copedent))

#(define (psg-copedent-num-strings copedent)
  (length (psg-copedent-strings copedent)))

#(define (psg-copedent-num-pedals-and-levers copedent)
  (length (psg-copedent-pedals-and-levers copedent)))

#(define (psg-copedent-id-list copedent)
  (map car (psg-copedent-pedals-and-levers copedent)))

#(define (psg-alterations-for-id copedent id)
  (define id-list (psg-copedent-id-list copedent))
  (define id-sublist (member id id-list))
  (if id-sublist
    (let 
      ((pedals-and-levers (psg-copedent-pedals-and-levers copedent)))
       (cdr (list-ref pedals-and-levers (- (length pedals-and-levers) (length id-sublist)))))
    (begin #f)))

%% Evaluation of copedents - here we define functions for deftermining the active tuning given a copedent and set of active pedals or levers

#(define (naturalize-pitch p)
   (let 
      ((o (ly:pitch-octave p))
       (a (* 4 (ly:pitch-alteration p)))    
       (n (ly:pitch-notename p)))
      (cond
        ((and (> a 1) (or (eqv? n 6) (eqv? n 2)))
        (set! a (- a 2))
        (set! n (+ n 1)))
        ((and (< a -1) (or (eqv? n 0) (eqv? n 3)))
         (set! a (+ a 2))
         (set! n (- n 1))))
      (cond
        ((> a 2) (set! a (- a 4)) (set! n (+ n 1)))
        ((< a -2) (set! a (+ a 4)) (set! n (- n 1))))
      (if (< n 0) (begin (set! o (- o 1)) (set! n (+ n 7))))
      (if (> n 6) (begin (set! o (+ o 1)) (set! n (- n 7))))
      (let 
        ((np (ly:make-pitch o n (/ a 4))))
        (if (equal? np p)
          (begin p)
          (naturalize-pitch np)))))

#(define (transpose-string pitch alter)
  (if (= alter 0)
    (begin pitch)
    (naturalize-pitch (ly:make-pitch
      (ly:pitch-octave pitch)
      (ly:pitch-notename pitch)
      (+ (ly:pitch-alteration pitch) (/ alter 2))))))

#(define (sum-alterations prev add)
  (if (and (not (= add 0)) (not (= prev 0)))
    (ly:error "Impossible pedal/lever combination"))
  (+ prev add))

#(define (calculate-alterations normal extended amount)
  (if (<= amount 1)
      (map (lambda (a) (* a amount)) normal)
      (map (lambda (a b) (+ (* (- amount 1) b) (* (- 2 amount) a))) normal extended)))

#(define (psg-evaluation-loop adjust copedent active)
  (if (null? active)
    (begin adjust)
    (let 
      ((alterations (psg-alterations-for-id copedent (caar active)))
       (amount (cadar active)))
      (if alterations
        (begin
          (set! adjust (psg-evaluation-loop adjust copedent (cdr active)))
          (map sum-alterations adjust (calculate-alterations (car alterations) (cadr alterations) amount)))
        (begin adjust)))))

#(define (psg-evaluate-copedent copedent active offset)
  (define strings (psg-copedent-strings copedent))
  (define adjust (map (lambda (x) (begin 0)) strings))
  
  (if (not (null? (psg-copedent-pedals-and-levers copedent)))
    (begin
      (set! adjust (psg-evaluation-loop adjust copedent active))
      (set! strings (map transpose-string strings adjust))))
  
  ; check whether to add an additional string for display style
  
  (if offset
    (append strings (list #{c''''''''#}))
    strings))

%% Clef stencil

#(define (psg-tab-clef-stencil copedent in-space style)
  (define (height-calculate in-space)
    (+ (* (- (psg-copedent-num-strings copedent) 1) 0.75) in-space))
  (let
    ((height (if in-space (height-calculate -0.55) (height-calculate -0.59)))
     (line-height (if in-space (* (psg-copedent-num-strings copedent) 1.5) (* (- (psg-copedent-num-strings copedent) 1) 1.5))))
   (lambda (grob)
    (grob-interpret-markup grob
      #{
       \markup
       \override #'(baseline-skip . 1.5)
       \concat
       {
        \hspace #-0.3
        #(case style
          ((0)
          #{
            \markup 
            \concat
            {
             \raise #height \center-column \sans \fontsize #-3 #(psg-string-numbers-makuplist copedent)
             \hspace #0.4
             \raise #height \center-column \sans \fontsize #-3 #(psg-string-names-markuplist copedent)
            }
          #})
          ((1)
          #{
            \markup \raise #height \center-column \sans \fontsize #-3 #(psg-string-numbers-makuplist copedent)
          #})
          ((2)
          #{
            \markup \raise #height \center-column \sans \fontsize #-3 #(psg-string-names-markuplist copedent)
          #}))
        \hspace #0.5
        \lower #(/ line-height 2) \draw-line #(cons 0 line-height)
       }
      #}))))

%% Pedal / lever stencil

#(define (make-psg-pedal-or-lever-text grob thickness in-parentheses)
  (define (width stencil) 
    (let 
      ((extent (ly:stencil-extent stencil X)))
      (- (cdr extent) (car extent))))
  (let* 
    ((amount (ly:grob-property grob 'psg-amount))
     (stencil (grob-interpret-markup grob (markup (ly:grob-property grob 'text))))
     (common (ly:grob-common-refpoint (ly:spanner-bound grob LEFT) (ly:spanner-bound grob RIGHT) X))
     (do-offset (not (unbroken-or-first-broken-spanner? grob)))
     (offsetX (if do-offset (cdr (ly:generic-bound-extent (ly:spanner-bound grob LEFT) common)) 0)))
    ; do parentheses if needed
    (if (or (= amount 0) in-parentheses) 
      (begin 
        (set! stencil (parenthesize-stencil stencil 0.05 0.2 0.6 0))
        (set! stencil (ly:stencil-translate stencil (cons (- 0 (car (ly:stencil-extent stencil X))) 0)))
      ))
    ; translate and return
    (ly:stencil-translate stencil (cons (if do-offset (- offsetX (width stencil)) 0) (- 0 (/ thickness 2))))))

#(define (make-psg-pedal-lever-line start-x start-y end-x end-y thickness arrow)
  (let 
    ((arrow-length 1)
     (arrow-width 0.6))
    (if arrow
      (ly:stencil-add
        (make-path-stencil (list 'moveto start-x start-y 'lineto (- end-x (/ arrow-length 2)) end-y) thickness 1 1 #f)
        (make-path-stencil (list 'moveto end-x end-y 'rlineto (- 0 arrow-length) (/ arrow-width 2) 'rlineto 0 (- 0 arrow-width)'closepath) thickness 1 1 #t))
      (make-path-stencil (list 'moveto start-x start-y 'lineto end-x end-y) thickness 1 1 #f))))
        
#(define (make-psg-pedal-or-lever-bracket grob text-padding text-offset thickness)
    (define (time-calculate a b c)
      (ly:moment-main (ly:moment-div (ly:moment-sub a b) (ly:moment-sub c b))))
    (define (interpolate a b c)
      (+ (* a (- 1 c)) (* b c)))
    (let*
      ((common (ly:grob-common-refpoint (ly:spanner-bound grob LEFT) (ly:spanner-bound grob RIGHT) X))
       (grob-ranks (ly:grob-spanned-column-rank-interval grob))
       (slow (ly:grob-property grob 'psg-slow #f))
       (slow-column (if (and slow (cadr slow)) (car slow) #f))
       (slow-rank (if slow-column (car (ly:grob-spanned-column-rank-interval slow-column)) #f))
       (slow-before (if slow-rank (<= slow-rank (car grob-ranks)) #f))
       (slow-after (if slow-rank (> slow-rank (cdr grob-ranks)) #f))
       (split-render (if slow-rank (and (not slow-before) (not slow-after)) #f))
       (slow-start (if slow-column (grob::when slow-column) #f))
       (slow-end (if slow-column (grob::when (ly:spanner-bound (ly:grob-original grob) RIGHT)) #f))
       (this-start (if slow-column (grob::when  (ly:spanner-bound grob LEFT)) #f))
       (this-end (if slow-column (grob::when  (ly:spanner-bound grob RIGHT)) #f))
       (amount (ly:grob-property grob 'psg-amount))
       (target-amount (if (and slow-rank (not slow-after)) (cadr slow) amount))
       (bracket-height (ly:grob-property grob 'bracket-height))
       (display-with-height (not (eq? (ly:grob-property grob 'psg-display-style) 'flat)))
       (start-height (if display-with-height (- bracket-height (* amount bracket-height)) 0))
       (end-height (if display-with-height (- bracket-height (* target-amount bracket-height)) 0))
       (bracket-offset text-offset)
       (absoluteL (ly:grob-relative-coordinate (ly:spanner-bound grob LEFT) common X))
       (relativeM (if split-render (- (ly:grob-relative-coordinate slow-column common X) absoluteL) #f))
       (relativeR (- (ly:grob-relative-coordinate (ly:spanner-bound grob RIGHT) common X) absoluteL))
       (arrow #f))
      ; calculate the height of the brackets for broken slow changes
      (if slow-column 
        (if display-with-height
          (begin 
            (if (ly:moment<? slow-start this-start) 
              (let 
                ((start-amount (interpolate amount target-amount (time-calculate this-start slow-start slow-end))))
                (set! start-height (- bracket-height (* start-amount bracket-height)))))
            (if (ly:moment<? this-end slow-end) 
              (let 
                ((end-amount (interpolate amount target-amount (time-calculate this-end slow-start slow-end))))
                (set! end-height (- bracket-height (* end-amount bracket-height))))))
         (begin 
            (set! start-height (/ bracket-height 2))
            (set! end-height (/ bracket-height 2))
            (set! arrow #t))))
      ; find the left edge of the bracket
      (if (not (unbroken-or-first-broken-spanner? grob)) 
        (set! bracket-offset (cdr (ly:generic-bound-extent (ly:spanner-bound grob LEFT) common))))
      ; find the right edge of the bracket
      (if (not-last-broken-spanner? grob)
        (set! relativeR (- (cdr (ly:generic-bound-extent (ly:spanner-bound grob RIGHT) common)) absoluteL))
        (if (ly:grob-property grob 'psg-continue #f)
          (set! relativeR (- relativeR text-padding))))
      (if split-render
       (make-path-stencil (list 'moveto bracket-offset start-height 'lineto relativeM start-height 'lineto relativeR end-height) thickness 1 1 #f)
       (if (or (not-last-broken-spanner? grob) (ly:grob-property grob 'psg-continue #f))
        (make-psg-pedal-lever-line bracket-offset start-height relativeR end-height thickness arrow)
        (make-path-stencil (list 'moveto bracket-offset start-height 'lineto relativeR start-height 'lineto relativeR bracket-height) thickness 1 1 #f)))))

#(define (psg-pedal-or-lever-bracket-stencil)
  (lambda (grob)
    (let*
      ((thickness 0.1)
       (text-padding 0.2)
       (restate-when-broken (ly:grob-property grob 'psg-restate-when-broken #f))
       (first-spanner (unbroken-or-first-broken-spanner? grob))
       (render-text (or first-spanner restate-when-broken))
       (text-stencil (if render-text (make-psg-pedal-or-lever-text grob thickness (or (not first-spanner) (ly:grob-property grob 'psg-restate #f))) #f))
       (text-extent (if render-text (ly:stencil-extent text-stencil X)))
       (text-offset (if render-text (+ text-padding (- (cdr text-extent) (car text-extent))) 0))
       (bracket (make-psg-pedal-or-lever-bracket grob text-padding text-offset thickness)))
      (if render-text (ly:stencil-add text-stencil bracket) bracket))))

%% Grobs and Interfaces

#(define (add-grob-definition grob-entry)
   (set! all-grob-descriptions
         (cons ((@@ (lily) completize-grob-entry) grob-entry) all-grob-descriptions)))

#(add-grob-definition `(PSGPedalOrLeverBracket
  . ((bracket-height . 0.9)
     (direction . ,DOWN)
     (font-series . bold)
     (font-shape . upright)
     (minimum-length . 0.3)
     (outside-staff-priority . 400)
     (padding . 0.5)
     (psg-display-style . height)
     (shorten-pair . (0 . 0))
     (staff-padding . 2.0)
     (stencil . ,(psg-pedal-or-lever-bracket-stencil))
     (style . line)
     (thickness . 1)
     (vertical-skylines . ,grob::unpure-vertical-skylines-from-stencil)
     (Y-offset . ,side-position-interface::y-aligned-side)
     (meta . ((class . Spanner)
              (interfaces . (font-interface
                             horizontal-bracket-interface
                             line-interface
                             outside-staff-interface
                             psg-pedal-or-lever-interface
                             side-position-interface
                             text-interface))
              (description . "A pedal steel pedal or level bracket."))))))

#(add-grob-definition `(PSGPedalOrLeverBracketLineSpanner
  . ((axes . (,Y))
     (cross-staff . ,ly:side-position-interface::calc-cross-staff)
     (direction . ,DOWN)
     (minimum-space . 1.2)
     (outside-staff-priority . 250)
     (padding . 0.6)
     (side-axis . ,Y)
     (slur-padding . 0.3)
     (staff-padding . 0.1)
     (vertical-skylines
      . ,grob::always-vertical-skylines-from-element-stencils)
     (X-extent . ,ly:axis-group-interface::width)
     (Y-extent . ,axis-group-interface::height)
     (Y-offset . ,side-position-interface::y-aligned-side)
     (meta . ((class . Spanner)
              (object-callbacks
               . ((pure-Y-common . ,ly:axis-group-interface::calc-pure-y-common)
                  (pure-relevant-grobs . ,ly:axis-group-interface::calc-pure-relevant-grobs)))
              (interfaces . (axis-group-interface
                             psg-pedal-or-lever-interface
                             psg-pedal-or-lever-line-spanner-interface
                             outside-staff-interface
                             side-position-interface))
              (description . "An auxiliary grob providing a vertical baseline to align pedal or lever brackets."))))))


#(ly:add-interface
  'psg-pedal-or-lever-interface
  "A pedal steel guitar lever or bracket."
  '())

#(ly:add-interface
  'psg-pedal-or-lever-line-spanner-interface
  "Pedal steel guitar lever or bracket line spanner."
  '())

%% Engraver

#(define (psg-valid-pedal-or-lever copedent id amount)
  (define alterations (psg-alterations-for-id copedent id))
  (if alterations
    (if (and (> amount 1) (null? (cadr alterations)))
      (begin
        (ly:warning "Pedal or lever ~a does not have extension - ignoring!" id)
        #f)
      #t)
    (begin
      (ly:warning "No pedal or lever with id ~a in copedent - ignoring!" id)
      #f)))

#(define (find-psg-id record id)
  (if (null? record)
    (begin #f)
    (if (equal? (caar record) id)
      (begin (cadar record))
      (find-psg-id (cdr record) id))))

#(define (remove-psg-id record id)
  (filter (lambda (x) (not (equal? (car x) id))) record))

#(define (add-psg-id record id data-object)
  (append record (list (list id data-object))))

#(define (psg-loop-and-clear record proc)
  (for-each proc record)
  (begin '()))

#(define (make-psg-change-markuplist id amount change)
  (let
    ((markuplist (if change (list (markup #:simple "")) (list (markup #:simple id))))
     (empty change))
    (if (> amount 1)
      (begin
        (append! markuplist (list (markup #:simple "+")))
        (set! amount (- amount 1))
        (set! empty #f)))
    (if (or empty (not (integer? amount)))
      (cond
        ((= amount 1) (append! markuplist (list (markup #:simple id))))
        ((= amount (/ 1 2)) (append! markuplist (list (markup #:simple "½"))))
        ((= amount (/ 1 3)) (append! markuplist (list (markup #:simple "⅓"))))
        ((= amount (/ 2 3)) (append! markuplist (list (markup #:simple "⅔"))))
        ((= amount (/ 1 4)) (append! markuplist (list (markup #:simple "¼"))))
        ((= amount (/ 3 4)) (append! markuplist (list (markup #:simple "¾"))))
        ((= amount (/ 1 5)) (append! markuplist (list (markup #:simple "⅕"))))
        ((= amount (/ 2 5)) (append! markuplist (list (markup #:simple "⅖"))))
        ((= amount (/ 3 5)) (append! markuplist (list (markup #:simple "⅗"))))
        ((= amount (/ 4 5)) (append! markuplist (list (markup #:simple "⅘"))))
        ((= amount (/ 1 6)) (append! markuplist (list (markup #:simple "⅙"))))
        ((= amount (/ 5 6)) (append! markuplist (list (markup #:simple "⅚"))))
        ((= amount (/ 1 8)) (append! markuplist (list (markup #:simple "⅛"))))
        ((= amount (/ 3 8)) (append! markuplist (list (markup #:simple "⅜"))))
        ((= amount (/ 5 8)) (append! markuplist (list (markup #:simple "⅝"))))
        ((= amount (/ 7 8)) (append! markuplist (list (markup #:simple "⅞"))))
        (else #f)))
    (begin markuplist)))

#(define (make-psg-change-markup id amount change)
 (markup (#:fontsize -4 (#:sans (#:bold (make-concat-markup (make-psg-change-markuplist id amount change)))))))

#(define (make-psg-bracket-grob context engraver id amount change restate event)
  (let
    ((grob (ly:engraver-make-grob engraver 'PSGPedalOrLeverBracket event))
     (column (ly:context-property context 'currentMusicalColumn)))
    (begin
      (ly:spanner-set-bound! grob LEFT column)
      (ly:grob-set-property! grob 'psg-id id)
      (ly:grob-set-property! grob 'psg-amount amount)
      (ly:grob-set-property! grob 'psg-restate restate)
      (ly:grob-set-property! grob 'text (make-psg-change-markup id amount change))
      grob)))

#(define (end-psg-bracket-grob context grobs id change amount)
  (let*
    ((grob (find-psg-id grobs id))
     (slow (ly:grob-property grob 'psg-slow #f)))
    (if change
      (begin
        (ly:spanner-set-bound! grob RIGHT (ly:context-property context 'currentMusicalColumn))
        (ly:grob-set-property! grob 'psg-continue #t)
        (if slow (ly:grob-set-property! grob 'psg-slow (list (car slow) amount (caddr slow)))))
      (ly:spanner-set-bound! grob RIGHT (ly:context-property context 'currentCommandColumn)))
    (remove-psg-id grobs id)))

#(define (set-psg-bracket-slow context id grobs event)
  (let
    ((column (ly:context-property context 'currentMusicalColumn))
     (grob (find-psg-id grobs id)))
    (ly:grob-set-property! grob 'psg-slow (list column #f event))))

#(define (psg-tab-engraver context)
  (define (display-style) (ly:assoc-get 'psg-display-style (ly:context-grob-definition context 'PSGPedalOrLeverBracket) #t #f))
  (let
    ((copedent (ly:context-property context 'psg-copedent))
     (in-space (ly:context-property context 'psg-tab-in-space))
     (clef-style (if (equal? (ly:context-property context 'psg-clef-style) 'both) 0 (if (equal? (ly:context-property context 'psg-clef-style) 'numbers) 1 2)))
     (active '())
     (changes '())
     (slow '())
     (grobs '())
     (clefs '())
     (note-heads '()))
    (make-engraver
      ;; ------- initialize -------
      ((initialize engraver)
        (if (not (psg-copedent? copedent))
          (ly:error "Copedent is not defined for PSGTabStaff"))
        (ly:context-set-property! context 'stringTunings (psg-evaluate-copedent copedent active in-space)))
      ;; ------- listeners -------
      (listeners
        ((psg-pedal-or-lever-event engraver event)
          (define dir (ly:event-property event 'span-direction))
          (define id (ly:event-property event 'psg-id))
          (define amount (ly:event-property event 'amount))
          (if (psg-valid-pedal-or-lever copedent id amount)
            (begin
              (if (eq? dir START)
                (if (not (find-psg-id active id))
                  (begin ;pedal/lever on
                    (set! active (add-psg-id active id amount))
                    (set! changes (add-psg-id changes id (list 1 amount event))))
                  (if (member (list id amount) active)
                    (ly:warning "Pedal or lever ~a re-engaged at the same amount without releasing/changing it" id)
                    (begin ;pedal/lever changed
                      (set! active (add-psg-id (remove-psg-id active id) id amount))
                      (set! changes (add-psg-id changes id (list 2 amount event))))))
                (if (find-psg-id active id)
                  (begin ;pedal/lever off
                    (set! active (remove-psg-id active id))
                    (set! changes (add-psg-id changes id (list 0 amount event))))
                  (ly:warning "Pedal or lever ~a released without engaging it" id)))
              (ly:context-set-property! context 'stringTunings (psg-evaluate-copedent copedent active in-space)))))
        ((psg-slow-pedal-or-lever-event engraver event)
          (define id (ly:event-property event 'psg-id))
          (if (not (find-psg-id active id))
            (begin ;pedal/lever on slow
              (set! active (add-psg-id active id 0))
              (set! changes (add-psg-id changes id (list 1 0 event))))
            (if (and (not (eq? (display-style) 'height)) (not (find-psg-id changes id)))
              (let
                ((amount (find-psg-id active id)))
                (set! active (add-psg-id (remove-psg-id active id) id amount))
                (set! changes (add-psg-id changes id (list -2 amount event))))))
          (if (psg-valid-pedal-or-lever copedent id 1)
            (set! slow (add-psg-id slow id event)))))
      ;; ------- acknowledgers -------
      (acknowledgers
        ((clef-interface engraver grob source-engraver)
          (set! clefs (cons grob clefs)))
        ((note-head-interface engraver grob source-engraver)
          (set! note-heads (cons grob note-heads))))
      ;; ------- process acknowledged -------
      ((process-acknowledged engraver)
        (set! clefs (psg-loop-and-clear clefs (lambda (clef)
            (ly:grob-set-property! clef 'stencil (psg-tab-clef-stencil copedent in-space clef-style)))))
        (if in-space
           (set! note-heads (psg-loop-and-clear note-heads (lambda (note-head)
              (ly:grob-set-property! note-head 'extra-offset '(0 . -0.5))
              (ly:grob-set-property! note-head 'font-size -3)
              (ly:grob-set-property! note-head 'whiteout #f))))))
      ;; ------- process music -------
      ((process-music engraver)
        (set! changes (psg-loop-and-clear changes (lambda (id-grob)                             
          (let
            ((id (car id-grob))
             (type (abs (caadr id-grob)))
             (restate (< (caadr id-grob) 0))
             (amount (cadadr id-grob))
             (event (car (cddadr id-grob))))
            (case type
              ((0) (set! grobs (end-psg-bracket-grob context grobs id #f amount)))
              ((1) (set! grobs (add-psg-id grobs id (make-psg-bracket-grob context engraver id amount #f restate event))))
              ((2) (set! grobs (end-psg-bracket-grob context grobs id #t amount)) (set! grobs (add-psg-id grobs id (make-psg-bracket-grob context engraver id amount #t restate event)))))))))
        (set! slow (psg-loop-and-clear slow (lambda (id-grob)                             
          (let
            ((id (car id-grob))
             (event (cadr id-grob)))
            (set-psg-bracket-slow context id grobs event))))))
      ;; ------- finalize -------
      ((finalize engraver)
       (set! grobs (psg-loop-and-clear grobs (lambda (id-grob)                             
          (let
            ((id (car id-grob)))
            (set! grobs (end-psg-bracket-grob context grobs id #f 0))))))))))

#(define (make-psg-alignment-grob context engraver idx)   
  (let
    ((grob (ly:engraver-make-grob engraver 'PSGPedalOrLeverBracketLineSpanner '()))
     (column (ly:context-property context 'currentCommandColumn)))
    (begin
      (ly:grob-set-property! grob 'outside-staff-priority (+ 250 (* 10 idx)))
      (ly:spanner-set-bound! grob LEFT column)
      grob)))

#(define (end-psg-alignment-grob context grob)
  (let
    ((column (ly:context-property context 'currentCommandColumn)))
    (ly:spanner-set-bound! grob RIGHT column)))

#(define (psg-tab-alignment-engraver context)
  (let
    ((copedent (ly:context-property context 'psg-copedent))
     (new-grobs '())
     (alignment-grobs '()))
    (make-engraver
      ;; ------- acknowledgers -------
      (acknowledgers
        ((psg-pedal-or-lever-interface engraver grob source-engraver)
          (set! new-grobs (cons grob new-grobs))))
      ;; ------- process acknowledged -------
      ((process-acknowledged engraver)
        (set! new-grobs (psg-loop-and-clear new-grobs (lambda (grob)
          (let
            ((id (ly:grob-property grob 'psg-id)))
            (ly:grob-set-property! grob 'Y-offset -2)
            (ly:axis-group-interface::add-element (find-psg-id alignment-grobs id) grob))))))
      ;; ------- process-music -------
      ((process-music engraver)
       (when (and (null? alignment-grobs) (not (null? (psg-copedent-id-list copedent))))
         (for-each (lambda (id idx)
          (set! alignment-grobs (add-psg-id alignment-grobs id (make-psg-alignment-grob context engraver idx)))) (psg-copedent-id-list copedent) (iota (length (psg-copedent-id-list copedent))))))
      ;; ------- finalize -------
      ((finalize engraver)
        (let
          ((column (ly:context-property context 'currentCommandColumn)))
          (set! alignment-grobs (psg-loop-and-clear alignment-grobs (lambda (id-grob)
            (end-psg-alignment-grob context (cadr id-grob))))))))))

%% Markup for copedents

#(define (psg-markuplist-loop idx to proc)
  (if (>= idx to)
    (list (proc idx))
    (append (list (proc idx)) (psg-markuplist-loop (+ idx 1) to proc))))

#(define (psg-pitch-to-markup pitch whiteout)
  (let
    ((alteration (ly:pitch-alteration pitch))
     (letter (string (integer->char (+ 65 (modulo (- (ly:pitch-notename pitch) 5) 7)))))
     (item (if whiteout #:whiteout #:simple)))
    (if (= alteration 0)
      (markup (begin item letter))
      (markup (begin item (make-concat-markup (list (markup #:simple letter) (markup (#:raise 0.6 (#:fontsize -4 (make-accidental-markup alteration)))))))))))

#(define (psg-string-numbers-makuplist copedent)
  (psg-markuplist-loop 1 (psg-copedent-num-strings copedent) (lambda (x) (markup (#:whiteout (number->string x))))))

#(define (psg-string-names-markuplist copedent)
  (define strings (psg-copedent-strings copedent))
  (psg-markuplist-loop 0 (- (psg-copedent-num-strings copedent) 1) (lambda (x) (markup (#:whiteout (psg-pitch-to-markup (list-ref strings x) #t))))))

#(define (psg-alteration-markup copedent id stringnum names)
  (define (get-pitch amount)
    (psg-pitch-to-markup (list-ref (psg-evaluate-copedent copedent (list (list id amount)) #f) stringnum) #f))
  (define alterations (psg-alterations-for-id copedent id))
  (define alt (car alterations))
  (define ext (cadr alterations))
  (define basic (list-ref alt stringnum))
  (define (numtostring x)
    (if (> x 0) (string-join (list "+" (number->string x)) "") (number->string x)))
  (if (or (null? ext) (= basic (list-ref ext stringnum)))
     (if (= basic 0)
        (markup #:simple "")
        (if names
          (get-pitch 1)
          (markup #:simple (numtostring basic))))
     (if names 
        (make-concat-markup (list (get-pitch 1) (markup #:simple "/") (get-pitch 2)))
        (make-concat-markup (list (markup #:simple (numtostring basic)) (markup #:simple "/") (markup #:simple (numtostring (list-ref ext stringnum))))))))

%% Copedent diagram markup

#(define-markup-command (psg-copedent-diagram-box layout props size text color)
  (number? markup? color?)
  (let
    ((width size)
     (height (/ size 2.5))
     (thickness (/ size 80)))
    (interpret-markup layout props
      #{
        \markup
        {
          \overlay
          {
            \override #'(line-cap-style . butt)
            \override #'(line-join-style . miter)
            \with-color #color
            \override #'(filled . #t) \path #thickness
              #`((moveto 0 0)
                (lineto ,width 0)
                (lineto ,width ,height)
                (lineto 0 ,height)
                (closepath))
            \translate #`(,(/ width 2) . ,(/ height 2)) \center-align \vcenter \sans \fontsize #-4 { #text }
          }
        }
      #})))

#(define (psg-string-loop copedent size id labelproc colorproc)
  (markup (#:override `(baseline-skip . ,(/ size 2.2)) (make-column-markup
    (psg-markuplist-loop 0 (psg-copedent-num-strings copedent)
      (lambda (x)
        (begin
          #{
            \markup \psg-copedent-diagram-box #size #(if (> x 0) (labelproc (- x 1)) (markup #:bold id)) #(colorproc x)
          #})))))))

#(define (psg-pedal-lever-loop copedent size headingcolor color1 color2 names)
  (define id-list (psg-copedent-id-list copedent))
  (define strings (psg-copedent-strings copedent))
  (psg-markuplist-loop 0 (psg-copedent-num-pedals-and-levers copedent)
    (lambda (x)
      (define id (if (> x 0) (list-ref id-list (- x 1)) ""))
      (let
        ((listproc (if (> x 0) (lambda (y) (psg-alteration-markup copedent id y names)) (lambda (y) (markup #:bold (psg-pitch-to-markup (list-ref strings y) #f)))))
         (colorproc (if (> x 0) (lambda (y) (if (> y 0) (if (= (modulo y 2) 1) color2 color1) headingcolor)) (lambda (y) (begin headingcolor)))))
        (psg-string-loop copedent size id listproc colorproc)))))

#(define-markup-command (psg-copedent-diagram layout props copedent size)
  (psg-copedent? number?)
  (let
    ((width size)
     (height (/ size 2))
     (textsize (- size 3)))
    (interpret-markup layout props
      #{
        \markup
        {
          \fontsize #textsize \override #`(word-space . ,(/ size 22)) \line #(psg-pedal-lever-loop copedent size  (rgb-color 0.7 0.7 0.7)  (rgb-color 0.88 0.88 0.88)  (rgb-color 0.95 0.95 0.95) #t)
        }
      #})))

%% Define the PedalSteelTab context

\layout
{
  \context
  {
    \Global
    \grobdescriptions #all-grob-descriptions
  }

  \context
  {
    \TabStaff
    \name PedalSteelTab
    \alias TabStaff
    \consists #psg-tab-engraver
    \consists #psg-tab-alignment-engraver
    
    psg-tab-in-space = ##t
    psg-clef-style = #'both
  }
  
  \inherit-acceptability PedalSteelTab TabStaff
  
  \context
  {
    \Staff
    \omit StringNumber
    \name PedalSteelStaff
    \alias Staff

    \omit StringNumber
  }
  
  \inherit-acceptability PedalSteelStaff Staff
  \inherit-acceptability Staff PedalSteelStaff
}