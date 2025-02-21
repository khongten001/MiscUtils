{
    Copyright (C) 2023 VCC
    creation date: Apr 2023
    initial release date: 23 Apr 2023

    author: VCC
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
    OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}


unit TestDynArraysMainCase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  DynArrays, Expectations;

type

  TTestDynArrays= class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSimpleAllocation;
    procedure TestWritingToArray;
    procedure TestReallocationToLargerArray;
    procedure TestReallocationToSmallerArray;

    procedure TestConcatDynArrays_HappyFlow;
    procedure TestConcatDynArray_WithEmpty;
    procedure TestConcatEmptyDynArray_WithValid;
    procedure TestConcatEmptyDynArray_WithEmpty;

    procedure Test_CallDynLength_WithoutInitDynArray;
    procedure Test_CallSetDynLength_WithoutInitDynArray;
    procedure Test_CallConcatDynArrays_WithoutFirstInitDynArray;
    procedure Test_CallConcatDynArrays_WithoutSecondInitDynArray;

    procedure TestDeleteFirstBytes_ZeroLength;
    procedure TestDeleteFirstBytes_LessThanLength;
    procedure TestDeleteFirstBytes_SameAsLength;
    procedure TestDeleteFirstBytes_GreaterThanLength;

    procedure TestCopyFromDynArray_HappyFlow;
    procedure TestCopyFromDynArray_0Length;
    procedure TestCopyFromDynArray_PartialOutOfContent;
    procedure TestCopyFromDynArray_CompletelyOutOfContent;
    procedure TestCopyFromDynArray_EmptySource;

    procedure TestDoubleFree;
  end;


implementation

{$IFDEF UsingDynTFT}
  uses
    MemManager;
{$ELSE}
  {$IFDEF UsingMPMM} //mP's memoy manager
    __Lib_MemManager  //users may still want to use a different flavor of the same memoy manager, without the DynTFT dependencies
  {$ELSE}
    //this is FP's memory manager
  {$ENDIF}
{$ENDIF}


const
  CUninitializedDynArrayErrMsg = 'The DynArray is not initialized. Please call InitDynArrayToEmpty before working with DynArray functions.';


procedure TTestDynArrays.SetUp;
begin
  {$IFDEF UsingDynTFT}
    MM_Init;
  {$ENDIF}

  {$IFDEF UsingMPMM}
    MM_Init;
  {$ENDIF}
end;


procedure TTestDynArrays.TearDown;
begin

end;


procedure TTestDynArrays.TestSimpleAllocation;
var
  Arr: TDynArrayOfByte;
  AllocationResult: Boolean;
begin
  InitDynArrayToEmpty(Arr);  //this is what Delphi and FP do automatically

  AllocationResult := SetDynLength(Arr, 7);
  try
    Expect(AllocationResult).ToBe(True, 'Expected a successful allocation.');
    Expect(Byte(AllocationResult)).ToBe(Byte(True));
    Expect(Arr.Len).ToBe(7);
  finally
    FreeDynArray(Arr);  //the array has to be manually freed, because there is no reference counting
  end;
end;


procedure TTestDynArrays.TestWritingToArray;
var
  Arr: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(Arr);
  SetDynLength(Arr, 20);
  try
    Arr.Content^[17] := 80;
    Expect(Arr.Content^[17]).ToBe(80);
  finally
    FreeDynArray(Arr);
  end;
end;


procedure TTestDynArrays.TestReallocationToLargerArray;
var
  Arr: TDynArrayOfByte;
  i: Integer;
begin
  InitDynArrayToEmpty(Arr);
  Expect(SetDynLength(Arr, 20)).ToBe(True);

  for i := 0 to DynLength(Arr) - 1 do
    Arr.Content^[i] := i * 10;

  Expect(SetDynLength(Arr, 30)).ToBe(True, 'expecting successful reallocation');
  try
    for i := 0 to 20 - 1 do  //test up to the old length, as this content has to be valid only
      Expect(Arr.Content^[i]).ToBe(DWord(i * 10));
  finally
    FreeDynArray(Arr);
  end;
end;


procedure TTestDynArrays.TestReallocationToSmallerArray;
var
  Arr: TDynArrayOfByte;
  i: Integer;
begin
  InitDynArrayToEmpty(Arr);
  SetDynLength(Arr, 20);

  for i := 0 to DynLength(Arr) - 1 do
    Arr.Content^[i] := i * 10;

  SetDynLength(Arr, 10);
  try
    for i := 0 to 10 - 1 do  //test up to the old length, as this content has to be valid only
      Expect(Arr.Content^[i]).ToBe(DWord(i * 10));
  finally
    FreeDynArray(Arr);
  end;
end;


procedure TTestDynArrays.TestConcatDynArrays_HappyFlow;
var
  Arr1, Arr2: TDynArrayOfByte;
  AllocationResult: Boolean;
  i: Integer;
begin
  InitDynArrayToEmpty(Arr1);
  InitDynArrayToEmpty(Arr2);

  try
    AllocationResult := SetDynLength(Arr1, 20);
    Expect(Byte(AllocationResult)).ToBe(Byte(True), 'Allocation_20 should succeed.');
    for i := 0 to DynLength(Arr1) - 1 do
      Arr1.Content^[i] := i * 10;
    Expect(Byte(AllocationResult)).ToBe(Byte(True), 'First allocation Result is overwritten.');

    AllocationResult := SetDynLength(Arr2, 15);
    Expect(Byte(AllocationResult)).ToBe(Byte(True), 'Allocation_15 should succeed.');
    for i := 0 to DynLength(Arr2) - 1 do
      Arr2.Content^[i] := i * 10;
    Expect(Byte(AllocationResult)).ToBe(Byte(True), 'Second allocation Result is overwritten.');

    AllocationResult := ConcatDynArrays(Arr1, Arr2);

    Expect(Byte(AllocationResult)).ToBe(Byte(True), 'Concat Result is overwritten or memory is full.');
    Expect(AllocationResult).ToBe(True);
    Expect(Arr1.Len).ToBe(35);

    for i := 0 to 20 - 1 do  //test up to the old length, as this content has to be valid only
      Expect(Arr1.Content^[i]).ToBe(DWord(i * 10));

    for i := 20 to 35 - 1 do  //test up to the old length, as this content has to be valid only
      Expect(Arr1.Content^[i]).ToBe(DWord((i - 20) * 10));
  finally
    FreeDynArray(Arr1);
    FreeDynArray(Arr2);
  end;
end;


procedure TTestDynArrays.TestConcatDynArray_WithEmpty;
var
  Arr1, Arr2: TDynArrayOfByte;
  AllocationResult: Boolean;
  i: Integer;
begin
  InitDynArrayToEmpty(Arr1);
  InitDynArrayToEmpty(Arr2);

  try
    AllocationResult := SetDynLength(Arr1, 20);
    for i := 0 to DynLength(Arr1) - 1 do
      Arr1.Content^[i] := i * 10;

    AllocationResult := ConcatDynArrays(Arr1, Arr2);
    Expect(AllocationResult).ToBe(True);
    Expect(Arr1.Len).ToBe(20);

    for i := 0 to 20 - 1 do  //test up to the old length, as this content has to be valid only
      Expect(Arr1.Content^[i]).ToBe(DWord(i * 10));
  finally
    FreeDynArray(Arr1);
    FreeDynArray(Arr2);
  end;
end;


procedure TTestDynArrays.TestConcatEmptyDynArray_WithValid;
var
  Arr1, Arr2: TDynArrayOfByte;
  AllocationResult: Boolean;
  i: Integer;
begin
  InitDynArrayToEmpty(Arr1);
  InitDynArrayToEmpty(Arr2);

  try
    AllocationResult := SetDynLength(Arr2, 15);
    for i := 0 to DynLength(Arr2) - 1 do
      Arr2.Content^[i] := i * 10;

    AllocationResult := ConcatDynArrays(Arr1, Arr2);
    Expect(AllocationResult).ToBe(True);
    Expect(Arr1.Len).ToBe(15);

    for i := 0 to 15 - 1 do  //test up to the old length, as this content has to be valid only
      Expect(Arr1.Content^[i]).ToBe(DWord(i * 10));
  finally
    FreeDynArray(Arr1);
    FreeDynArray(Arr2);
  end;
end;


procedure TTestDynArrays.TestConcatEmptyDynArray_WithEmpty;
var
  Arr1, Arr2: TDynArrayOfByte;
  AllocationResult: Boolean;
begin
  InitDynArrayToEmpty(Arr1);
  InitDynArrayToEmpty(Arr2);

  try
    AllocationResult := ConcatDynArrays(Arr1, Arr2);
    Expect(AllocationResult).ToBe(True);
    Expect(Arr1.Len).ToBe(0);
  finally
    FreeDynArray(Arr1);
    FreeDynArray(Arr2);
  end;
end;


procedure TTestDynArrays.Test_CallDynLength_WithoutInitDynArray;
var
  Arr: TDynArrayOfByte;
begin
  try
    DynLength(Arr);
  except
    on E: Exception do
      Expect(E.Message).ToBe(CUninitializedDynArrayErrMsg);
  end;
end;


procedure TTestDynArrays.Test_CallSetDynLength_WithoutInitDynArray;
var
  Arr: TDynArrayOfByte;
begin
  try
    SetDynLength(Arr, 3);
  except
    on E: Exception do
      Expect(E.Message).ToBe(CUninitializedDynArrayErrMsg);
  end;
end;


procedure TTestDynArrays.Test_CallConcatDynArrays_WithoutFirstInitDynArray;
var
  Arr1, Arr2: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(Arr2);
  SetDynLength(Arr2, 3);

  try
    ConcatDynArrays(Arr1, Arr2);
  except
    on E: Exception do
      Expect(E.Message).ToBe(CUninitializedDynArrayErrMsg);
  end;

  FreeDynArray(Arr2);
end;


procedure TTestDynArrays.Test_CallConcatDynArrays_WithoutSecondInitDynArray;
var
  Arr1, Arr2: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(Arr1);
  SetDynLength(Arr1, 3);

  try
    ConcatDynArrays(Arr1, Arr2);
  except
    on E: Exception do
      Expect(E.Message).ToBe(CUninitializedDynArrayErrMsg);
  end;

  FreeDynArray(Arr1);
end;


procedure TTestDynArrays.TestDeleteFirstBytes_ZeroLength;
var
  Arr: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(Arr);
  SetDynLength(Arr, 3);
  Arr.Content^[0] := 30;
  Arr.Content^[1] := 40;
  Arr.Content^[2] := 50;

  RemoveStartBytesFromDynArray(0, Arr);

  Expect(Arr.Len).ToBe(3);
  Expect(Arr.Content^[0]).ToBe(30);
  Expect(Arr.Content^[1]).ToBe(40);
  Expect(Arr.Content^[2]).ToBe(50);

  FreeDynArray(Arr);
end;


procedure TTestDynArrays.TestDeleteFirstBytes_LessThanLength;
var
  Arr: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(Arr);
  SetDynLength(Arr, 3);
  Arr.Content^[0] := 30;
  Arr.Content^[1] := 40;
  Arr.Content^[2] := 50;

  RemoveStartBytesFromDynArray(2, Arr);

  Expect(Arr.Len).ToBe(1);
  Expect(Arr.Content^[0]).ToBe(50);

  FreeDynArray(Arr);
end;


procedure TTestDynArrays.TestDeleteFirstBytes_SameAsLength;
var
  Arr: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(Arr);
  SetDynLength(Arr, 3);
  Arr.Content^[0] := 30;
  Arr.Content^[1] := 40;
  Arr.Content^[2] := 50;

  RemoveStartBytesFromDynArray(3, Arr);

  Expect(Arr.Len).ToBe(0);

  FreeDynArray(Arr);
end;


procedure TTestDynArrays.TestDeleteFirstBytes_GreaterThanLength;
var
  Arr: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(Arr);
  SetDynLength(Arr, 3);
  RemoveStartBytesFromDynArray(7, Arr);

  Expect(Arr.Len).ToBe(0);

  FreeDynArray(Arr);
end;


procedure TTestDynArrays.TestCopyFromDynArray_HappyFlow;
var
  Src, Dest: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(Src);
  Expect(StringToDynArrayOfByte('0123456789ABCDEF', Src)).ToBe(True);
  CopyFromDynArray(Dest, Src, 3, 7);

  Expect(DynArrayOfByteToString(Dest)).ToBe('3456789');
end;


procedure TTestDynArrays.TestCopyFromDynArray_0Length;
var
  Src, Dest: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(Src);
  Expect(StringToDynArrayOfByte('0123456789ABCDEF', Src)).ToBe(True);
  CopyFromDynArray(Dest, Src, 3, 0);

  Expect(DynArrayOfByteToString(Dest)).ToBe('');
end;


procedure TTestDynArrays.TestCopyFromDynArray_PartialOutOfContent;
var
  Src, Dest: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(Src);
  Expect(StringToDynArrayOfByte('0123456789ABCDEF', Src)).ToBe(True);
  CopyFromDynArray(Dest, Src, 10, 20);

  Expect(DynArrayOfByteToString(Dest)).ToBe('ABCDEF');
end;


procedure TTestDynArrays.TestCopyFromDynArray_CompletelyOutOfContent;
var
  Src, Dest: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(Src);
  Expect(StringToDynArrayOfByte('0123456789ABCDEF', Src)).ToBe(True);
  CopyFromDynArray(Dest, Src, 50, 20);

  Expect(DynArrayOfByteToString(Dest)).ToBe('');
end;


procedure TTestDynArrays.TestCopyFromDynArray_EmptySource;
var
  Src, Dest: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(Src);
  CopyFromDynArray(Dest, Src, 0, 20);

  Expect(DynArrayOfByteToString(Dest)).ToBe('');
end;


procedure TTestDynArrays.TestDoubleFree;
var
  Arr: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(Arr);
  SetDynLength(Arr, 3);

  FreeDynArray(Arr);
  Expect(Arr.Len).ToBe(0);
  Expect(Arr.Content).ToBe(nil);

  try                            //Free again. The structure should stay the same. No exception is expected.
    FreeDynArray(Arr);
    Expect(Arr.Len).ToBe(0);
    Expect(Arr.Content).ToBe(nil);
  except
    on E: Exception do
      Expect(E.Message).ToBe('No exception is expected!');
  end;
end;


initialization

  RegisterTest(TTestDynArrays);
end.

