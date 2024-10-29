import deque

when isMainModule:
  var deq1 = newDeque[int]()
  assert deq1.isEmpty
  assert deq1.len == 0
  assert deq1.capacity == 4
  assert deq1.low == -1
  assert deq1.high == -1
  
  deq1 = [1, 2, 3].toDeque
  assert not deq1.isEmpty
  assert deq1.len == 3
  assert deq1.capacity == 4
  assert deq1 == @@[1, 2, 3]
  assert deq1[deq1.high .. deq1.low] == deq1.reversed

  deq1.addFirst(10)
  deq1.addLast(40)
  deq1.first = 0
  deq1.last = 4
  assert deq1.len == 5
  assert deq1.capacity == 8
  assert deq1 == @@[0, 1, 2, 3, 4]

  deq1.insert([10, 20], 2)
  assert deq1 == @@[0, 1, 10, 20, 2, 3, 4]
  assert deq1.last == 4
  assert deq1.first == 0
  deq1[3..2] = [100, 200, 300, 400, 500]    # note reversed indices
  assert deq1 == @@[0, 1, 200, 100, 2, 3, 4]    # extra elements in source ignored

  deq1.delete(2 .. 3)
  deq1.dropFirst
  assert deq1 == @@[1, 2, 3, 4]
  deq1 &= 5
  deq1 &= @[6]
  assert deq1 == [1, 2, 3, 4, 5, 6].toDeque
  deq1 &= [7]
  assert deq1 == [1, 2, 3, 4, 5, 6, 7].toDeque
