#
#
#            Nim's Runtime Library
#        (c) Copyright 2012 Andreas Rumpf
#     customized by Charles Fout, October 2024
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## An implementation of a `Deque`:idx: (double-ended queue).
## The underlying implementation uses a `seq`.
##
## .. note:: None of the procs that get an individual value from the Deque should be used
##   on an empty Deque.
##
## If compiled with the `boundChecks` option, those procs will raise an `IndexDefect`
## on such access. This should not be relied upon, as `-d:danger` or `--checks:off` will
## disable those checks and then the procs may return garbage or crash the program.
##
## As such, a check to see if the Deque is empty is needed before any
## access, unless your program logic guarantees it indirectly.

runnableExamples:
  var a = [10, 20, 30, 40].toDeque
  doAssertRaises(IndexDefect, echo a[4])
  assert not isEmpty(a)
  
  a.addLast(50)
  assert $a == "[10, 20, 30, 40, 50]"
  assert a.first == 10
  assert a.last == 50
  assert len(a) == 5
  assert capacity(a) == 8

  assert a.popFirst == 10
  assert a.popLast == 50
  assert a.len == 3
  assert a.capacity == 8
  assert a.high == 2

  a.addFirst(11)
  a.addFirst(22)
  a.addFirst(33)
  a.first = 44
  assert a == @@[44, 22, 11, 20, 30, 40]

  a.shrink(fromFirst = 1, fromLast = 2)
  assert a == @@[22, 11, 20]


import std/[assertions, hashes]  # sequtils removed, no longer used
from math import nextPowerOfTwo
from algorithm import reversed

type
  Deque*[T] = object
    ## A double-ended queue backed with a ringed `seq` buffer.
    ##
    ## To initialize an empty Deque,
    ## use the `initDeque proc <#initDeque,int>`_.

    data: seq[T]

    # `head` and `tail` are masked only when accessing an element of `data`
    # so that `tail - head == data.len` when the Deque is full.
    # They are uint so that incrementing/decrementing them doesn't cause
    # over/underflow. You can get a number of items with `tail - head`
    # even if `tail` or `head` is wrapped around and `tail < head`, because
    # `tail - head == (uint.high + 1 + tail) - head` when `tail < head`.

    head, tail: uint

const
  defaultInitialSize* = 4

template destroy(x: untyped) =
  reset(x)

template `^^`(s, i: untyped): untyped =
  (when i is BackwardsIndex: s.len - int(i) else: int(i))

template initImpl(result: typed, initialSize: Natural) =
  let correctSize = nextPowerOfTwo(initialSize)
  newSeq(result.data, correctSize)

template checkIfInitialized(deq: typed) =
  if deq.data.len == 0:
    initImpl(deq, defaultInitialSize)
    
template isEmpty*[T](deq: Deque[T]): bool =
  ## Returns true is `deq` is empty, false otherwise.
  deq.head == deq.tail

template mask[T](deq: Deque[T]): uint =
  uint(deq.data.len) - 1

proc initDeque*[T](initialSize: Natural = defaultInitialSize): Deque[T] =
  ## Creates a new empty Deque of capacity `initialSize`.
  ## The length of a newly created Deque will be 0.
  ## Capacity is always a power of two, with a minimum of two.
  ##
  ## (default and capacity: `defaultInitialSize <#defaultInitialSize>`_).
  ##
  ## **See also:**
  ## * `newDeque proc <#newDeque,Natural>`_
  ## * `toDeque proc <#toDeque,sinkopenArray[T]>`_

  runnableExamples:
    var deq1 = initDeque[int](6)
    assert capacity(deq1) == 8
    assert len(deq1) == 0

  result.initImpl(max(initialSize, 2))

proc newDeque*[T](initialSize: Natural = defaultInitialSize): Deque[T] =
  ## Creates a new empty Deque of capacity `initialSize`.
  ## The length of a newly created Deque will be 0.
  ## Capacity is always a power of two, with a minimum of two.
  ##
  ## (default capacity: `defaultInitialSize <#defaultInitialSize>`_).
  ##
  ## **See also:**
  ## * `initDeque proc <#initDeque,Natural>`_
  ## * `toDeque proc <#toDeque,sinkopenArray[T]>`_

  runnableExamples:
    var deq1 = newDeque[int]()
    assert capacity(deq1) == defaultInitialSize
    assert len(deq1) == 0

  result.initImpl(max(initialSize, 2))

template reset*[T](deq: var Deque[T], maxCap: Natural = defaultInitialSize) =
  ## Resets `deq` so it is empty and sets its capacity to `maxCap`.  
  ## Capacity is always a power of two.
  ## 
  ## **See also:**
  ## * `clear template <#clear.t,Deque[T]>`_
  ## * `defaultInitialSize constant <#defaultInitialSize>`_
  
  destroy(deq)
  setLen(deq.data, nextPowerOfTwo(maxCap))

template clear*[T](deq: var Deque[T]) =
  ## Resets the Deque so that it is empty, but retains its capacity.
  ##
  ## **See also:**
  ## * `reset template <#reset.t,Deque[T],Natural>`_
  
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    clear(a)
    assert len(a) == 0
    assert capacity(a) == 8

  let maxCap = len(deq.data)
  destroy(deq)
  setLen(deq.data, maxCap)

template len*[T](deq: Deque[T]): int =
  ## Returns the number of elements in `deq`.
  int(deq.tail - deq.head)

template high*[T](deq: Deque[T]): int =
  ## Returns the highest valid index in `deq`.  This is the same as len(deq) - 1.
  ## If `deq` is empty, will return -1.
  int(deq.tail - deq.head) - 1

template low*[T](deq: Deque[T]): int =
  ## Returns the lowest valid index in `deq`, normally 0.
  ## If `deq` is empty, will return -1.
  if len(deq) == 0:
    -1.int
  else:
    0.int

template capacity*[T](deq: Deque[T]): int =
  ## Returns the maximum capacity of the sequence backing `deq`.  
  ## Capacity is always a power of two.
  runnableExamples:
    var deq = [1, 2, 3, 4].toDeque
    assert deq.len == deq.capacity
    deq.addLast(5)
    assert deq.len == 5
    assert deq.capacity == 8
    
  assert len(deq.data) == capacity(deq.data)
  len(deq.data)

template emptyCheck(deq) =
  # Bounds check for the regular Deque access.
  when compileOption("boundChecks"):
    if unlikely(deq.len < 1):
      raise newException(IndexDefect, "Empty Deque.")

template xBoundsCheck(deq, i) =
  # Bounds check for the array like accesses.
  when compileOption("boundChecks"): # `-d:danger` or `--checks:off` should disable this.
    if unlikely(i >= deq.len): # x < deq.low is taken care by the Natural parameter
      raise newException(IndexDefect,
                         "Deque index out of bounds: " & $i & " > " & $(deq.high))
    if unlikely(i < 0): # when used with BackwardsIndex
      raise newException(IndexDefect,
                         "Deque index out of bounds: " & $i & " < 0")

proc expandIfNeeded[T](deq: var Deque[T], count: Natural = 1)
proc normalize[T](target: var Deque[T])
proc makeRoom[T](target: var Deque[T], pos: Natural, howMany: Natural)
# forward declarations

proc `[]`*[T](deq: Deque[T], i: Natural): T {.inline.} =
  ## Accesses the `i`-th element of `deq`.
  runnableExamples:
    let a = [10, 20, 30, 40, 50].toDeque
    assert a[0] == 10
    assert a[3] == 40
    doAssertRaises(IndexDefect, echo a[8])

  xBoundsCheck(deq, i)
  return deq.data[(deq.head + i.uint) and deq.mask]

proc `[]`*[T](deq: var Deque[T], i: Natural): var T {.inline.} =
  ## Accesses the `i`-th element of `deq` and returns a mutable
  ## reference to it.
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    inc(a[0])
    assert a[0] == 11

  xBoundsCheck(deq, i)
  return deq.data[(deq.head + i.uint) and deq.mask]

proc `[]`*[T](deq: Deque[T], i: BackwardsIndex): T {.inline.} =
  ## Accesses the backwards indexed `i`-th element.
  ##
  ## `deq[^1]` is the last element.
  runnableExamples:
    let a = [10, 20, 30, 40, 50].toDeque
    assert a[^1] == 50
    assert a[^4] == 20
    doAssertRaises(IndexDefect, echo a[^9])

  xBoundsCheck(deq, deq.len - int(i))
  return deq[deq.len - int(i)]

proc `[]`*[T](deq: var Deque[T], i: BackwardsIndex): var T {.inline.} =
  ## Accesses the backwards indexed `i`-th element and returns a mutable
  ## reference to it.
  ##
  ## `deq[^1]` is the last element.
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    inc(a[^1])
    assert a[^1] == 51

  xBoundsCheck(deq, deq.len - int(i))
  return deq[deq.len - int(i)]


proc `[]`*[T; U, V: Ordinal](target: Deque[T], x: HSlice[U, V]): Deque[T] {.systemRaisesDefect.} =
  ## Slice operation for Deques.
  ## Returns the inclusive range `[target[start .. stop]`.
  ## If the slice indices are reversed, so will be the data.
  ##   ```nim
  ##   var s = @[1, 2, 3, 4].toDeque
  ##   assert $s[0..2] == "[1, 2, 3]"
  ##   assert $s[1..<4] == "[2, 3]"
  ##   assert $s[^1..0] == "[4, 3, 2, 1]"
  ##   ```
  var start = target ^^ x.a
  var stop = target ^^ x.b
  var backwards = false
  xBoundsCheck(target, start)
  xBoundsCheck(target, stop)
  if stop < start:
    #raise newException(IndexDefect, "Deque indices reversed: " & $start & " > " & $stop)
    swap(start, stop)
    backwards = true
  let howLong = stop - start + 1
  var newData = newSeq[T](nextPowerOfTwo(howLong))
  if not backwards:
    for i in 0 ..< howLong: newData[i] = target[i + start]
  else:
    let last = howLong - 1
    for i in 0 ..< howLong: newData[last - i] = target[i + start]
  result.data = move newData
  result.head = 0.uint
  result.tail = howLong.uint


proc `[]=`*[T](deq: var Deque[T], i: Natural, val: sink T) {.inline.} =
  ## Sets the `i`-th element of `deq` to `val`.
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    a[0] = 99
    a[3] = 66
    assert $a == "[99, 20, 30, 66, 50]"

  checkIfInitialized(deq)
  xBoundsCheck(deq, i)
  deq.data[(deq.head + i.uint) and deq.mask] = val

proc `[]=`*[T](deq: var Deque[T], i: BackwardsIndex, x: sink T) {.inline.} =
  ## Sets the backwards indexed `i`-th element of `deq` to `x`.
  ##
  ## `deq[^1]` is the last element.
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    a[^1] = 99
    a[^3] = 77
    assert $a == "[10, 20, 77, 40, 99]"

  checkIfInitialized(deq)
  xBoundsCheck(deq, deq.len - int(i))
  deq[deq.len - int(i)] = x

proc `[]=`*[T; U, V: Ordinal](target: var Deque[T], x: HSlice[U, V], source: Deque[T]) {.systemRaisesDefect.} =
  ## Slice assignment for Deques from Deques.
  ##
  ## If `source` is longer than the slice, a slice of `source` is taken to fit.
  ## If `source` is shorter than the slice, `target` is shortened.
  ## If the slice indices are reversed, so will be the data.
  runnableExamples:
    var s = @[1, 2, 3, 4, 5].toDeque
    s[1 .. ^2] = @[10, 20].toDeque
    assert s == @[1, 10, 20, 5].toDeque

  var start = target ^^ x.a
  var stop = target ^^ x.b
  var backwards = false
  xBoundsCheck(target, start)
  xBoundsCheck(target, stop)
  if stop < start:
    # raise newException(IndexDefect, "Deque indices reversed: " & $start & " > " & $stop)
    swap(start, stop)
    backwards = true
  let howLong = stop - start + 1
  var data1 = newSeq[T](len(target))
  for count, _ in target: data1[count] = target[count]
  var data2 = newSeq[T](len(source))
  for count, _ in source: data2[count] = source[count]
  if len(data2) <= howlong:
    data1[start..stop] = if not backwards: data2 else: data2.reversed
  else:
    data1[start..stop] = if not backwards: data2[0..<howLong] else: data2[0..<howLong].reversed
  target = data1.toDeque

proc `[]=`*[T; U, V: Ordinal](target: var Deque[T], x: HSlice[U, V], source: openArray[T]) {.systemRaisesDefect.} =
  ## Slice assignment for Deques from sequences.
  ##
  ## If `source` is longer than the slice, a slice of `source` is taken to fit.
  ## If `source` is shorter than the slice, `target` is shortened.
  ## If the slice indices are reversed, so will be the data.
  runnableExamples:
    var s = @[1, 2, 3, 4, 5].toDeque
    s[1 .. ^2] = @[10, 20]
    assert s == @[1, 10, 20, 5].toDeque
    s[1..0] = @[100, 200]
    assert s == @[200, 100, 20, 5].toDeque

  var start = target ^^ x.a
  var stop = target ^^ x.b
  var backwards = false
  xBoundscheck(target, start)
  xBoundsCheck(target, stop)
  if stop < start:
    # raise newException(IndexDefect, "Deque indices reversed: " & $start & " > " & $stop)
    swap(start, stop)
    backwards = true
  let howLong = stop - start + 1
  var data1 = newSeq[T](len(target))
  for count, _ in target: data1[count] = target[count]
  if len(source) <= howlong:
    data1[start..stop] = if not backwards: source else: source.reversed
  else:
    data1[start..stop] = if not backwards: source[0 ..< howLong] else: source[0 ..< howLong].reversed
  target = data1.toDeque

iterator items*[T](deq: Deque[T]): T {.inline.} =
  ## Yields every element of `deq`.
  ##
  ## **See also:**
  ## * `mitems iterator <#mitems.i,Deque[T]>`_
  ## * `backwards iterator <#backwards.i,Deque[T]>`_
  runnableExamples:
    let a = [10, 20, 30, 40, 50].toDeque
    var b: seq[int]
    for item in a: b.add(item)
    assert b == @[10, 20, 30, 40, 50]
    assert $a == "[10, 20, 30, 40, 50]"

  var c = 0
  let stop = deq.len
  while c < stop:
    yield deq.data[(deq.head + c.uint) and deq.mask]
    inc c

iterator mitems*[T](deq: var Deque[T]): var T {.inline.} =
  ## Yields every element of `deq`, which can be modified.
  ##
  ## **See also:**
  ## * `items iterator <#items.i,Deque[T]>`_
  ## * `backwardsMut iterator <#backwardsMut.i,Deque[T]>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    for x in mitems(a):
      x = 5 * x - 1
    assert $a == "[49, 99, 149, 199, 249]"

  var c = 0
  let stop = deq.len
  while c < stop:
    yield deq.data[(deq.head + c.uint) and deq.mask]
    inc c

iterator pairs*[T](deq: Deque[T]): tuple[key: int, val: T] {.inline.} =
  ## Yields every `(position, value)`-pair of `deq`.
  ##
  ## **See also:**
  ## * `backwardsPairs iterator <#backwardsPairs.i,Deque[T]>`_
  runnableExamples:
    import std/sequtils
    let a = [10, 20, 30].toDeque
    assert toSeq(a.pairs) == @[(0, 10), (1, 20), (2, 30)]

  var c = 0
  let stop = deq.len
  while c < stop:
    yield (c, deq.data[(deq.head + c.uint) and deq.mask])
    inc c

iterator backwards*[T](deq: Deque[T]): T {.inline.} =
  ## Yields each element of `deq` in reverse order.
    ##
  ## **See also:**
  ## * `items iterator <#items.i,Deque[T]>`_
  ## * `backwardsMut iterator <#backwardsMut.i,Deque[T]>`_
  runnableExamples:
    let thisDeq = [1, 2, 3, 4, 5].toDeque
    var thatDeq = [6].toDeque
    for item in backwards(thisDeq):
      thatDeq.addLast(item)
    assert thisDeq == [1, 2, 3, 4, 5].toDeque
    assert thatdeq == [6, 5, 4, 3, 2, 1].toDeque
  
  var c = deq.high
  while c >= 0:
    yield deq.data[(deq.head + c.uint) and deq.mask]
    dec c

iterator backwardsMut*[T](deq: var Deque[T]): var T {.inline.} =
  ## Yields in reverse order a mutable version of every element of `deq`.
  ##
  ## **See also:**
  ## * `mitems iterator <#mitems.i,Deque[T]>`_
  ## * `backwards iterator <#backwards.i,Deque[T]>`_
  runnableExamples:
    var thisDeq = [1, 2, 3, 4, 5].toDeque
    var thatDeq = [12].toDeque
    var otherDeq = @@[6]
    for item in backwardsMut(thisDeq):
      otherDeq.addFirst(item)
      item *= 2
      thatDeq.addLast(item)
    assert thisDeq == [2, 4, 6, 8, 10].toDeque
    assert thatDeq == [12, 10, 8, 6, 4, 2].toDeque
    assert otherDeq == @@[1, 2, 3, 4, 5, 6]
  
  var c = deq.high
  while c >= 0:
    yield deq.data[(deq.head + c.uint) and deq.mask]
    dec c

iterator backwardsPairs*[T](deq: Deque[T]): tuple[key: int, val: T] {.inline.} =
  ## Yields every `(position, value)`-pair of `deq` in reverse order.
  ##
  ## **See also:**
  ## * `pairs iterator <#pairs.i,Deque[T]>`_
  runnableExamples:
    import std/sequtils
    let a = [10, 20, 30].toDeque
    assert toSeq(a.backwardsPairs) == @[(2, 30), (1, 20), (0, 10)]

  var c = deq.high
  while c >= 0:
    yield (c, deq.data[(deq.head + c.uint) and deq.mask])
    dec c

proc contains*[T](deq: Deque[T], item: T): bool {.inline.} =
  ## Returns true if `item` is in `deq` or false if not found.
  ##
  ## Usually used via the `in` operator.
  ## It is the equivalent of `deq.find(item) >= 0`.
  runnableExamples:
    let q = [7, 9].toDeque
    assert 7 in q
    assert q.contains(7)
    assert 8 notin q

  for e in deq:
    if e == item: return true
  return false

proc expandIfNeeded[T](deq: var Deque[T], count: Natural = 1) =
  checkIfInitialized(deq)
  let cap = capacity(deq.data)
  assert deq.data.len == cap
  assert deq.len <= cap
  if unlikely((deq.len + count) > cap):
    var n = newSeq[T](nextPowerOfTwo(deq.len + count))
    var i = 0
    for x in mitems(deq):
      when nimvm: n[i] = x # workaround for VM bug
      else: n[i] = move(x)
      inc i
    deq.data = move(n)
    deq.tail = len(deq).uint
    deq.head = 0

proc addFirst*[T](deq: var Deque[T], item: sink T) =
  ## Adds an `item` to the beginning of `deq`.
  ##
  ## **See also:**
  ## * `addLast proc <#addLast,Deque[T],sinkT>`_
  ## * `& proc <#&,sinkDeque[T],sinkT>`_
  runnableExamples:
    var a = initDeque[int]()
    for i in 1 .. 5:
      a.addFirst(10 * i)
    assert $a == "[50, 40, 30, 20, 10]"

  expandIfNeeded(deq)
  dec deq.head
  deq.data[deq.head and deq.mask] = item
  
template pushFirst*[T](deq: var Deque[T], item: sink T) =
  ## **Alias for:**
  ## * `addFirst proc <#addFirst,Deque[T],sinkT>`_
  addFirst(deq, item)

proc addFirst*[T](deq1: var Deque[T], deq2: sink Deque[T]) =
  ## Adds `deq2` to the beginning of `deq1` as concatenation.
  ##
  ## **See also:**
  ## * `addLast proc <#addLast,Deque[T],sinkDeque[T]>`_
  runnableExamples:
    var a = [1, 2, 3].toDeque
    let b = [10, 20, 30].toDeque
    a.addFirst(b)
    assert $a == "[10, 20, 30, 1, 2, 3]"

  expandIfNeeded(deq1, len(deq2))
  let howMany = deq2.high
  if howMany < 0: return
  for i in 0 .. howMany:
    deq1.addFirst(deq2[howMany - i])
    
template pushFirst*[T](deq1: var Deque[T], deq2: sink Deque[T]) =
  ## **Alias for:**
  ## * `addFirst proc <#addFirst,Deque[T],sinkDeque[T]>`_
  addFirst(deq1, deq2)
    
proc addFirst*[T](deq1: var Deque[T], seq2: sink openArray[T]) =
  ## Adds `deq2` to the beginning of `deq1` as concatenation.
  ##
  ## **See also:**
  ## * `addLast proc <#addLast,Deque[T],sinkopenArray[T]>`_
  runnableExamples:
    var a = [1, 2, 3].toDeque
    let b = [10, 20, 30]
    a.addFirst(b)
    assert $a == "[10, 20, 30, 1, 2, 3]"

  expandIfNeeded(deq1, len(seq2))
  let howMany = seq2.high
  if howMany < 0: return
  for i in 0 .. howMany:
    deq1.addFirst(seq2[howMany - i])
    
template pushFirst*[T](deq1: var Deque[T], seq2: sink openArray[T]) =
  ## **Alias for:**
  ## * `addFirst proc <#addFirst,Deque[T],sinkopenArray[T]>`_
  addFirst(deq1, seq2)

proc addLast*[T](deq: var Deque[T], item: sink T) =
  ## Adds an `item` to the end of `deq`.
  ##
  ## **See also:**
  ## * `addFirst proc <#addFirst,Deque[T],sinkT>`_
  ## * `& proc <#&,sinkDeque[T],sinkT>`_
  ## * `&= template <#&=.t,Deque[T],sinkT>`_
  runnableExamples:
    var a = initDeque[int]()
    for i in 1 .. 5:
      a.addLast(10 * i)
    assert $a == "[10, 20, 30, 40, 50]"

  expandIfNeeded(deq)
  deq.data[deq.tail and deq.mask] = item
  inc deq.tail

template pushLast*[T](deq: var Deque[T], item: sink T) =
  ## **Alias for:**
  ## * `addLast proc <#addLast,Deque[T],sinkT>`_
  addLast(deq, item)

proc addLast*[T](deq1: var Deque[T], deq2: sink Deque[T]) =
  ## Adds `deq2` to the end of `deq1` as concatenation.
  ##
  ## **See also:**
  ## * `addFirst proc <#addFirst,Deque[T],sinkDeque[T]>`_
  ## * `& proc <#&,sinkDeque[T],sinkDeque[T]>`_
  ## * `&= template <#&=.t,Deque[T],sinkDeque[T]>`_
  runnableExamples:
    var a = [1, 2, 3].toDeque
    let b = [10, 20, 30].toDeque
    a.addLast(b)
    assert $a == "[1, 2, 3, 10, 20, 30]"

  expandIfNeeded(deq1, len(deq2))
  let howMany = deq2.high
  if howMany < 0: return
  for i in 0 .. howMany:
    deq1.addLast(deq2[i])

template pushLast*[T](deq1: var Deque[T], deq2: sink Deque[T]) =
  ## **Alias for:**
  ## * `addLast proc <#addLast,Deque[T],sinkDeque[T]>`_
  addLast(deq1, deq2)

proc addLast*[T](deq1: var Deque[T], seq2: sink openArray[T]) =
  ## Adds `deq2` to the end of `deq1` as concatenation.
  ##
  ## **See also:**
  ## * `addFirst proc <#addFirst,Deque[T],sinkDeque[T]>`_
  ## * `& proc <#&,sinkDeque[T],sinkDeque[T]>`_
  ## * `&= template <#&=.t,Deque[T],sinkDeque[T]>`_
  runnableExamples:
    var a = [1, 2, 3].toDeque
    let b = @[10, 20, 30]
    a.addLast(b)
    assert $a == "[1, 2, 3, 10, 20, 30]"

  expandIfNeeded(deq1, len(seq2))
  let howMany = seq2.high
  if howMany < 0: return
  for i in 0 .. howMany:
    deq1.addLast(seq2[i])

template pushLast*[T](deq1: var Deque[T], seq2: sink openArray[T]) =
  ## **Alias for:**
  ## * `addLast proc <#addLast,Deque[T],sinkopenArray[T]>`_
  addLast(deq1, seq2)

proc toDeque*[T](x: sink openArray[T]): Deque[T] =
  ## Creates a new Deque that contains the elements of `x` (in the same order).
  ##
  ## **See also:**
  ## * `initDeque proc <#initDeque,Natural>`_
  ## * `newDeque proc <#newDeque,Natural>`_
  ## * `toDeque template <#toDeque.t,Deque[T]>`_
  ## * `@@ template <#@@.t,openArray[T]>`_
  runnableExamples:
    let a = toDeque([7, 8, 9])
    assert len(a) == 3
    assert $a == "[7, 8, 9]"

  result.initImpl(x.len)
  for item in items(x):
    result.addLast(item)

template toDeque*[T](deq: Deque[T]): Deque[T] =
  ## Returns a copy of `deq`.
  ##
  ## **See also:**
  ## * `toDeque proc <#toDeque,sinkopenArray[T]>`_
  ## * `@@ template <#@@.t,Deque[T]>`_
  deq

template `@@`*[T](x: openArray[T]): Deque[T] =
  ## Creates a new Deque that contains the elements of `x` (in the same order).
  ##
  ## **See also:**
  ## * `toDeque proc <#toDeque,sinkopenArray[T]>`_
  runnableExamples:
    let thisDeq = @@[1, 2, 3]
    assert thisDeq == [1, 2, 3].todeque
    assert $thisDeq == "[1, 2, 3]"
  
  toDeque(x)
  
template `@@`*[T](deq: Deque[T]): Deque[T] =
  ## Returns a copy of `deq`.
  ##
  ## **See also:**
  ## * `toDeque template <#toDeque.t,Deque[T]>`_
  deq

proc first*[T](deq: Deque[T]): T {.inline.} =
  ## Returns the first element of `deq`, but does not remove it from the Deque.
  ##
  ## **See also:**
  ## * `first proc <#first,Deque[T]_2>`_ which returns a mutable reference
  ## * `last proc <#last,Deque[T]>`_
  runnableExamples:
    let a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    assert a.first == 10
    assert len(a) == 5

  emptyCheck(deq)
  result = deq.data[deq.head and deq.mask]

proc last*[T](deq: Deque[T]): T {.inline.} =
  ## Returns the last element of `deq`, but does not remove it from the Deque.
  ##
  ## **See also:**
  ## * `last proc <#last,Deque[T]_2>`_ which returns a mutable reference
  ## * `first proc <#first,Deque[T]>`_
  runnableExamples:
    let a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    assert a.last == 50
    assert len(a) == 5

  emptyCheck(deq)
  result = deq.data[(deq.tail - 1) and deq.mask]

proc first*[T](deq: var Deque[T]): var T {.inline.} =
  ## Returns a mutable reference to the first element of `deq`,
  ## but does not remove it from the Deque.
  ##
  ## **See also:**
  ## * `first proc <#first,Deque[T]>`_
  ## * `last proc <#last,Deque[T]_2>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    first(a) = 99
    assert $a == "[99, 20, 30, 40, 50]"
    inc a.first
    assert $a == "[100, 20, 30, 40, 50]"

  emptyCheck(deq)
  result = deq.data[deq.head and deq.mask]

proc last*[T](deq: var Deque[T]): var T {.inline.} =
  ## Returns a mutable reference to the last element of `deq`,
  ## but does not remove it from the Deque.
  ##
  ## **See also:**
  ## * `first proc <#first,Deque[T]_2>`_
  ## * `last proc <#last,Deque[T]>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    a.last() = 99
    assert $a == "[10, 20, 30, 40, 99]"
    inc a.last
    assert $a == "[10, 20, 30, 40, 100]"

  emptyCheck(deq)
  result = deq.data[(deq.tail - 1) and deq.mask]

proc `first=`*[T](deq: var Deque[T], item: sink T) {.inline.} =
  ## Alters the first element of `deq`.
  ##
  ## **See also:**
  ## * `first proc <#first,Deque[T]>`_
  ## * `last proc <#last,Deque[T]_2>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    a.first = 99
    assert $a == "[99, 20, 30, 40, 50]"

  emptyCheck(deq)
  deq[0] = item

proc `last=`*[T](deq: var Deque[T], item: sink T){.inline.} =
  ## Alters the last element of `deq`.
  ##
  ## **See also:**
  ## * `first proc <#first,Deque[T]_2>`_
  ## * `last proc <#last,Deque[T]>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    a.last = 99
    assert $a == "[10, 20, 30, 40, 99]"

  emptyCheck(deq)
  deq[deq.high] = item

proc popFirst*[T](deq: var Deque[T]): T {.inline, discardable.} =
  ## Removes and returns the first element of the `deq`.
  ##
  ## See also:
  ## * `popLast proc <#popLast,Deque[T]>`_
  ## * `shrink proc <#shrink,Deque[T],int,int>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    assert a.popFirst == 10
    assert $a == "[20, 30, 40, 50]"

  emptyCheck(deq)
  result = move deq.data[deq.head and deq.mask]
  inc deq.head

proc popLast*[T](deq: var Deque[T]): T {.inline, discardable.} =
  ## Removes and returns the last element of the `deq`.
  ##
  ## **See also:**
  ## * `popFirst proc <#popFirst,Deque[T]>`_
  ## * `shrink proc <#shrink,Deque[T],int,int>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    assert a.popLast == 50
    assert $a == "[10, 20, 30, 40]"

  emptyCheck(deq)
  dec deq.tail
  result = move deq.data[deq.tail and deq.mask]


proc dropFirst*[T](deq: var Deque[T]) {.inline.} =
  ## Removes the first element of the `deq`.
  ##
  ## See also:
  ## * `popFirst proc <#popFirst,Deque[T]>`_
  ## * `dropLast proc <#dropLast,Deque[T]>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    a.dropFirst
    assert $a == "[20, 30, 40, 50]"

  emptyCheck(deq)
  destroy deq.data[deq.head and deq.mask]
  inc deq.head

proc dropLast*[T](deq: var Deque[T]) {.inline.} =
  ## Removes the last element of the `deq`.
  ##
  ## **See also:**
  ## * `dropFirst proc <#dropFirst,Deque[T]>`_
  ## * `popLast proc <#popLast,Deque[T]>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    a.dropLast
    assert $a == "[10, 20, 30, 40]"

  emptyCheck(deq)
  dec deq.tail
  destroy deq.data[deq.tail and deq.mask]

proc shrink*[T](deq: var Deque[T], fromFirst = 0, fromLast = 0) =
  ## Removes `fromFirst` elements from the front of the Deque and
  ## `fromLast` elements from the back.
  ##
  ## If the supplied number of elements exceeds the total number of elements
  ## in the Deque, the Deque will remain empty.
  ##
  ## **See also:**
  ## * `clear template <#clear.t,Deque[T]>`_
  ## * `dropFirst proc <#dropFirst,Deque[T]>`_
  ## * `dropLast proc <#dropLast,Deque[T]>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    a.shrink(fromFirst = 2, fromLast = 1)
    assert $a == "[30, 40]"

  if fromFirst + fromLast > deq.len:
    clear(deq)
    return
  for i in 0 ..< fromFirst:
    destroy(deq.data[deq.head and deq.mask])
    inc deq.head
  for i in 0 ..< fromLast:
    dec deq.tail
    destroy(deq.data[deq.tail and deq.mask])

proc setLen*[T](target: var Deque[T], length: Natural) =
  ## Sets the length of `target` to `length`, increasing its capacity if needed.
  let howLong = len(target)
  if length == howLong: return
  if length > howLong:
    expandIfNeeded(target, length - howLong)
    target.tail += (length - howLong).uint
  else:
    shrink(target, 0, howLong - length)

proc setCap*[T](target: var Deque[T], length: Natural) =
  ## Sets the capacity of `target` to `length`, shrinking or growing as needed.
  ## Capacity will always be a power of two.
  let tLen = len(target)
  let tCap = capacity(target)
  if length == tCap: return
  if length == 0:
    target = initDeque[T](0)
  if length > tcap:
    expandIfNeeded(target, length - tcap)
  else:
    var seq1 = newSeq[T](nextPowerOfTwo(length))
    for i in 0 ..< min(length, tLen):
      seq1[i] = target[i]
    destroy target.data
    target.data = seq1
    target.head = 0.uint
    target.tail = min(length, tLen).uint

proc `$`*[T](deq: Deque[T]): string =
  ## Turns a Deque into its string representation.
  runnableExamples:
    let a = [10, 20, 30].toDeque
    assert $a == "[10, 20, 30]"

  result = "["
  for x in deq:
    if result.len > 1: result.add(", ")
    result.addQuoted(x)
  result.add("]")

func `==`*[T](deq1, deq2: Deque[T]): bool =
  ## The `==` operator for Deque.
  ## Returns `true` if both Deques contains the same values in the same order.
  runnableExamples:
    var a, b = initDeque[int]()
    a.addFirst(2)
    a.addFirst(1)
    b.addLast(1)
    b.addLast(2)
    doAssert a == b

  if deq1.len != deq2.len:
    return false

  for i in 0 ..< deq1.len:
    if deq1.data[(deq1.head + i.uint) and deq1.mask] != deq2.data[(deq2.head +
        i.uint) and deq2.mask]:
      return false

  true

func hash*[T](deq: Deque[T]): Hash =
  ## Hashing of Deque.
  var h: Hash = 0
  for x in deq:
    h = h !& hash(x)
  !$h

proc normalize[T](target: var Deque[T]) =
  checkIfInitialized(target)
  if len(target) == 0 or target.head == 0:
    return
  var newDeq = initDeque[T](capacity(target))
  for item in target:
    newDeq.addLast(item)
  target = move newDeq

proc makeRoom[T](target: var Deque[T], pos: Natural, howMany: Natural) =
  if howMany == 0:
    return
  expandIfNeeded(target, howMany)
  let lastPos = target.high
  target.tail += howMany.uint
  if len(target) == howMany or pos == lastPos + 1: # Insert just after last element = concat
    return
  when compileOption("boundChecks"): # `-d:danger` or `--checks:off` should disable this.
    if unlikely(pos > lastPos + 1): # pos < deq.low is taken care by the Natural parameter
      raise newException(IndexDefect,
                         "Out of bounds: " & $pos & " > " & $(lastPos + 1))
  for i in countdown(lastPos, pos):
    target.data[i + howMany] = move target.data[i]

proc insert*[T](target: var Deque[T], source: sink T, pos: Natural) =
  ## Insert `source` element into `target` Deque in front of position `pos`.
  checkIfInitialized(target)
  normalize(target)
  makeRoom(target, pos, 1)
  target.data[pos] = source

proc insert*[T](target: var Deque[T], source: sink openArray[T], pos: Natural) =
  ## Insert `source` sequence into `target` Deque in front of position `pos`.
  checkIfInitialized(target)
  if unlikely len(source) == 0:
    return
  normalize(target)
  makeRoom(target, pos, len(source))
  for count, item in source:
    target.data[pos + count] = item

proc insert*[T](target: var Deque[T], source: sink Deque[T], pos: Natural) =
  ## Insert `source` Deque into `target` Deque in front of position `pos`.
  checkIfInitialized(target)
  if unlikely len(source) == 0: return
  normalize(target)
  makeRoom(target, pos, len(source))
  for count, item in source:
    target.data[pos + count] = item

proc reverse*[T](target: var Deque[T]) =
  ## Reverses `target` in place.
  checkIfInitialized(target)
  var lo = target.low
  var hi = target.high
  while lo < hi:
    swap(target[lo], target[hi])
    dec(hi)
    inc(lo)

proc reversed*[T](source: Deque[T]): Deque[T] =
  ## Returns a reversed copy of `source`.
  if unlikely len(source) == 0: return
  for item in source:
    result.addFirst(item)

proc `&`*[T](x, y: sink Deque[T]): Deque[T] {.noSideEffect.} =
  ## Returns the concatenation of two Deques.
  ##
  ## See also:
  ## * `addLast(var Deque[T], sink Deque[T]) <#addLast,Deque[T],sinkDeque[T]>`_
  ## * `&= template <#&=.t,Deque[T],sinkDeque[T]>`_
  result = x
  result.addLast(y)

proc `&`*[T](x: sink Deque[T], y: sink T): Deque[T] {.noSideEffect.} =
  ## Returns element `y` appended to the end of Deque `x`.
  ##
  ## See also:
  ## * `addLast(var Deque[T], T) <#addLast,Deque[T],sinkT>`_
  ## * `&= template <#&=.t,Deque[T],sinkT>`_
  result = x
  result.addLast(y)

proc `&`*[T](x: sink T, y: sink Deque[T]): Deque[T] {.noSideEffect.} =
  ## Returns element `x` prepended to the beginning of Deque `y`.
  ##
  ## See also:
  ## * `addFirst(var Deque[T], T) <#addFirst,Deque[T],sinkT>`_
  result = y
  result.addFirst(x)

proc `&`*[T](x: sink openArray[T], y: sink Deque[T]): Deque[T] {.noSideEffect.} =
  ## Returns seq `x` prepended to the beginning of Deque `y`.
  ##
  ## See also:
  ## * `addFirst(var Deque[T], sink openArray[T]) <#addFirst,Deque[T],sinkopenArray[T]>`_
  result = y
  result.addFirst(x)

proc `&`*[T](x: sink Deque[T], y: sink openArray[T]): Deque[T] {.noSideEffect.} =
  ## Returns seq `y` appended to the end of Deque `x`.
  ##
  ## See also:
  ## * `addLast(var Deque[T], sink openArray[T]) <#addLast,Deque[T],sinkopenArray[T]>`_
  ## * `&= template <#&=.t,Deque[T],sinkseq[T]>`_
  result = x
  result.addLast(y)

template `&=`*[T](deq1: var Deque[T], deq2: sink Deque[T]) =
  ## Appends `deq2` to `deq1`
  ##
  ## See also:
  ## * `addLast(var Deque[T], sink Deque[T]) <#addLast,Deque[T],sinkDeque[T]>`_
  ## * `&=(var Deque[T], sink T) template <#&=.t,Deque[T],sinkT>`_
  ## * `&=(var Deque[T], sink seq[T]) template <#&=.t,Deque[T],sinkseq[T]>`_
  ## * `&=(var Deque[T], sink array[N, T]) template <#&=.t,Deque[T],sinkarray[N,T]>`_
  ## * `& proc <#&,sinkDeque[T],sinkDeque[T]>`_

  addLast(deq1, deq2)

template `&=`*[T](deq1: var Deque[T], seq2: sink seq[T]) =
  ## Appends `seq2` to `deq1`
  ##
  ## See also:
  ## * `addLast(var Deque[T], sink Deque[T]) <#addLast,Deque[T],sinkDeque[T]>`_
  ## * `&=(var Deque[T], sink T) template <#&=.t,Deque[T],sinkT>`_
  ## * `&=(var Deque[T], sink Deque[T]) template <#&=.t,Deque[T],sinkDeque[T]>`_
  ## * `&=(var Deque[T], sink array[N, T]) template <#&=.t,Deque[T],sinkarray[N,T]>`_
  ## * `& proc <#&,sinkDeque[T],sinkDeque[T]>`_

  addLast(deq1, seq2)
  
template `&=`*[T, N](deq1: var Deque[T], arr2: sink array[N, T]) =
  ## Appends `arr2` to `deq1`
  ##
  ## See also:
  ## * `addLast(var Deque[T], sink Deque[T]) <#addLast,Deque[T],sinkDeque[T]>`_
  ## * `&=(var Deque[T], sink T) template <#&=.t,Deque[T],sinkT>`_
  ## * `&=(var Deque[T], sink Deque[T]) template <#&=.t,Deque[T],sinkDeque[T]>`_
  ## * `&=(var Deque[T], sink seq[T]) template <#&=.t,Deque[T],sinkseq[T]>`_
  ## * `& proc <#&,sinkDeque[T],sinkDeque[T]>`_
  
  # openArray did not work, so had to specify separate operators for seq and array.

  addLast(deq1, arr2)

template `&=`*[T](deq: var Deque[T], what: sink T) =
  ## Appends `what` to `deq`
  ##
  ## See also:
  ## * `addLast(var Deque[T], sink T) <#addLast,Deque[T],sinkT>`_
  ## * `&=(var Deque[T], sink Deque[T]) template <#&=.t,Deque[T],sinkDeque[T]>`_
  ## * `&=(var Deque[T], sink seq[T]) template <#&=.t,Deque[T],sinkseq[T]>`_
  ## * `&=(var Deque[T], sink array[N, T]) template <#&=.t,Deque[T],sinkarray[N,T]>`_
  ## * `& proc <#&,sinkDeque[T],sinkT>`_

  addLast(deq, what)

proc delete*[T](deq: var Deque[T], where: Natural) {.systemRaisesDefect.} =
  ## Deletes the element at `where`, moving down all elements higher than that.
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    delete(a, 3)
    assert $a == "[10, 20, 30, 50]"
    assert a.len == 4

  if unlikely len(deq) < 1: return
  xBoundsCheck(deq, where)
  destroy deq[where]
  if where < deq.high:
    for count in where ..< deq.high:
      deq[count] = move deq[count + 1]
  dec deq.tail

proc delete*[T](deq: var Deque[T], where: BackwardsIndex) {.systemRaisesDefect.} =
  ## Deletes the element at backwards index `where`, moving down all elements higher than that.
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    a.delete(^2)
    assert $a == "[10, 20, 30, 50]"
    assert a.len == 4

  if unlikely len(deq) < 1: return
  let here = len(deq) - int(where)
  xBoundsCheck(deq, here)
  destroy deq[here]
  if here < deq.high:
    for count in here ..< deq.high:
      deq[count] = move deq[count + 1]
  dec deq.tail


proc delete*[T; U, V: Ordinal](target: var Deque[T], x: HSlice[U, V]) {.systemRaisesDefect.} =
  ## Deletes the elements at slice `x`, moving down all elements higher than that.
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    a.delete(1..2)
    assert $a == "[10, 40, 50]"
    assert a.len == 3

  var start = target ^^ x.a
  var stop = target ^^ x.b
  var backwards = false
  xBoundscheck(target, start)
  xBoundsCheck(target, stop)
  if stop < start:
    # raise newException(IndexDefect, "Deque indices reversed: " & $start & " > " & $stop)
    swap(start, stop)
    backwards = true # ToDo: maybe adjust from front if backwards?
  let howLong = stop - start + 1
  for i in start .. stop:
    destroy target[i]
  if stop < target.high:
    for i in (stop + 1) .. target.high:
      target[i - howLong] = move target[i]
  target.tail -= howLong.uint

proc rotR*[T](deq: var Deque[T], howMany: Natural = 1) {.inline.} =
  ## Rotate each element of `deq` `howMany` places to the right, wrapping around.
  ## Default is one.
  ##
  ## **See also:**
  ## * `rotL proc <#rotL,Deque[T],Natural>`_
  runnableExamples:
    var deq = @@[1, 2, 3, 4, 5]
    deq.rotR
    assert deq == @@[5, 1, 2, 3, 4]
    rotR(deq, 2)
    assert deq == @@[3, 4, 5, 1, 2]
    deq.rotR(0)
    assert deq == [3, 4, 5, 1, 2].toDeque
  
  if unlikely deq.isEmpty: return
  deq.expandIfNeeded(1)
  for i in 1 .. howMany:
    dec deq.head
    dec deq.tail
    deq.data[deq.head and deq.mask] = move deq.data[deq.tail and deq.mask]
    #deq.addFirst(popLast(deq))

template rotateRight*[T](deq: var Deque[T], howMany: Natural = 1) =
  ## **Alias for:**
  ## * `rotR proc <#rotR,Deque[T],Natural>`_
  rotR(deq, howMany)

proc rotL*[T](deq: var Deque[T], howMany: Natural = 1) {.inline.} =
  ## Rotate each element of `deq` `howMany` places to the left, wrapping around.
  ## Default is one.
  ##
  ## **See also:**
  ## * `rotR proc <#rotR,Deque[T],Natural>`_
  runnableExamples:
    var deq = @@[1, 2, 3, 4, 5]
    deq.rotL
    assert deq == @@[2, 3, 4, 5, 1]
    rotL(deq, 3)
    assert deq == @@[5, 1, 2, 3, 4]
    
  if unlikely deq.isEmpty: return
  deq.expandIfNeeded(1)
  for i in 1 .. howMany:
    deq.data[deq.tail and deq.mask] = move deq.data[deq.head and deq.mask]
    inc deq.head
    inc deq.tail
    # deq.addLast(popFirst(deq))
    
template rotateLeft*[T](deq: var Deque[T], howMany: Natural = 1) =
  ## **Alias for:**
  ## * `rotL proc <#rotL,Deque[T],Natural>`_
  rotL(deq, howMany)

proc extract*[T](deq: var Deque[T], where: Natural): T =
  ## Remove the element at position `where` from `deq` and return it.
  runnableExamples:
    var deq1 = @@[1, 2, 3, 4, 5]
    var three = deq1.extract(2)
    assert three == 3
    assert deq1 == @@[1, 2, 4, 5]
    
  emptyCheck(deq)
  result = deq[where]
  deq.delete(where)
  
proc extract*[T](deq: var Deque[T], where: BackwardsIndex):  T =
  ## Remove the element at backwards indexed position `where` from `deq` and return it.
  runnableExamples:
    var deq1 = @@[1, 2, 3, 4, 5]
    assert deq1[^3] == 3
    var three = deq1.extract(^3)
    assert three == 3
    assert deq1 == @@[1, 2, 4, 5]
    
  emptyCheck(deq)
  result = deq[where]
  deq.delete(where)

proc extract*[T; U, V: Ordinal](deq: var Deque[T], where: HSlice[U, V]):  Deque[T] =
  ## Remove the elements at slice `where` from `deq` and return them as a new Deque.
  runnableExamples:
    var deq1 = @@[1, 2, 3, 4, 5]
    assert deq1[^3] == 3
    var middle = deq1.extract(3..1) # backwards slices work
    assert middle == @@[4, 3, 2]
    assert deq1 == @@[1, 5]
    
  emptyCheck(deq)
  result = deq[where]
  deq.delete(where)
