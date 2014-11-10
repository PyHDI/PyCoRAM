#include <stdio.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "lib.h"

#define LOADER_SIZE (256)

// 128 MB
#define INFO_OFFSET (MMAP_MEMORY + 0x0000000)
#define PAGE_OFFSET (MMAP_MEMORY + 0x0000100)
#define NODE_OFFSET (MMAP_MEMORY + 0x6000000)
#define IDTB_OFFSET (MMAP_MEMORY + 0x7000000)
#define ADTB_OFFSET (MMAP_MEMORY + 0x7400000)
#define HEAP_OFFSET (MMAP_MEMORY + 0x7800000)

//------------------------------------------------------------------------------
#define MAX_NODES (4 * 1024 * 1024)
#define MAX_PAGES (256 * 1024)
#define PAGE_SIZE (8)

#define MAX_INT (0xffffffff)

typedef unsigned int Uint;
typedef struct node Node;
typedef struct page Page;
typedef struct edge Edge;

#include "heap.h"

struct node
{
  Node* parent_node;
  Uint current_cost;
  Page* page_addr;
  Uint visited;
};

struct edge
{
  Node* next_node;
  Uint cost;
};

struct page
{
  Uint num_entries;
  Page* next_page;
  Edge edges [PAGE_SIZE];
};

//------------------------------------------------------------------------------
Uint number_of_nodes;
Uint number_of_edges;

Node* node_array;
Page* page_array;
Uint* id_table;  // Address -> ID
Node** addr_table;  // ID -> Address

PriorityQueue pqueue;

Uint node_index; // for node count
Uint page_index; // for edge count

//------------------------------------------------------------------------------
static Uint __x = 123456789;
static Uint __y = 362436069;
static Uint __z = 521288629;
static Uint __w = 88675123; 

Uint xorshift()
{ 
  Uint t;
  t = __x ^ (__x << 11);
  __x = __y; __y = __z; __z = __w;
  return __w = (__w ^ (__w >> 19)) ^ (t ^ (t >> 8)); 
}

void reset_xorshift()
{
  __x = 123456789;
  __y = 362436069;
  __z = 521288629;
  __w = 88675123; 
}

//------------------------------------------------------------------------------
void my_sleep(Uint t)
{
  volatile Uint i;
  for(i = 0; i < t; i++);
}

//------------------------------------------------------------------------------
Node* get_node(Uint id)
{
  return addr_table[id];
}

//------------------------------------------------------------------------------
Uint get_id(Node* node)
{
  Uint index = (Uint)((((void*) node) - ((void*) node_array))) / sizeof(Node);
  return id_table[index];
}

//------------------------------------------------------------------------------
Node* add_node(Uint id)
{
  Node* ret = get_node(id);
  if(ret == NULL){
    number_of_nodes++;
    node_array[node_index].parent_node = NULL;
    node_array[node_index].current_cost = MAX_INT;
    node_array[node_index].page_addr = NULL;
    node_array[node_index].visited = 0;
    id_table[node_index] = id;
    addr_table[id] = &node_array[node_index];
    ret = &node_array[node_index];
    node_index++;
    return ret;
  }
  return ret;
}

//------------------------------------------------------------------------------
void add_edge(Uint from, Uint to, Uint cost)
{
  number_of_edges++;

  Node* f = add_node(from);
  Node* t = add_node(to);

  if(f->page_addr == NULL){
    // New page
    f->page_addr = &page_array[page_index];
    page_index++;

    f->page_addr->next_page = NULL;
    f->page_addr->num_entries = 0;
  }

  Page* p = f->page_addr;
  while(p->next_page != NULL){
    p = p->next_page;
  }
  
  if(p->num_entries < PAGE_SIZE){
    p->edges[p->num_entries].next_node = t;
    p->edges[p->num_entries].cost = cost;
    p->num_entries++;
  }else{
    // New page
    p->next_page = &page_array[page_index];
    page_index++;

    p->next_page->next_page = NULL;
    p->next_page->num_entries = 0;

    p = p->next_page;
    p->edges[p->num_entries].next_node = t;
    p->edges[p->num_entries].cost = cost;
    p->num_entries++;
  }
}

//------------------------------------------------------------------------------
void add_frontier(Node* node, Uint cost)
{
  Heapelement he;
  he.value = cost;

  he.data = node;
  enqueue(he, &pqueue);
}

//------------------------------------------------------------------------------
void update_frontiers(Node* current_node)
{
  Uint current_cost = current_node->current_cost;
  Page* page = current_node->page_addr;

  while(page != NULL){
    Uint num_next = page->num_entries;
    Uint i;

    for(i=0; i<num_next; i++){
      //printf("page[%d]\n", i);
      Uint cost = page->edges[i].cost;
      Uint new_cost = current_cost + cost;
      Node* next_node = page->edges[i].next_node;
      if(next_node->current_cost > new_cost){
        //printf("add node:%d cost:%d\n", get_id(next_node), new_cost);
        add_frontier(next_node, new_cost);
        next_node->current_cost = new_cost;
        next_node->parent_node = current_node;
      }
    }
    
    page = page->next_page;
  }
}

//------------------------------------------------------------------------------
int is_frontier_empty()
{
  return is_empty(&pqueue);
}

//------------------------------------------------------------------------------
Node* select_frontier()
{
  //printf("current size=%d\n", pqueue.size);
  Heapelement he = dequeue(&pqueue);
  Node* n = he.data;
  return n;
}

//------------------------------------------------------------------------------
Uint find_shortest_path(Uint start, Uint goal)
{
  Node* current_node = get_node(start);
  Node* goal_node = get_node(goal);
  current_node->current_cost = 0;
  add_frontier(current_node, 0);

  while(current_node != goal_node){
    if(is_frontier_empty()) return MAX_INT;
    current_node = select_frontier();
    if(current_node->visited) continue;
    current_node->visited = 1;
    //printf("current_node=%d current_cost=%d\n", current_node->id, current_node->current_cost);
    update_frontiers(current_node);
  }

  return current_node->current_cost;
}

//------------------------------------------------------------------------------
void walk_result(Uint sum_of_cost, Uint start, Uint goal)
{
  Node* c = get_node(goal);
  //printf("route: ");
  mylib_display_char('r');
  mylib_display_char('o');
  mylib_display_char('u');
  mylib_display_char('t');
  mylib_display_char('e');
  mylib_display_char(':');
  mylib_display_char(' ');
  mylib_display_newline();

  while(c != NULL){
    Uint id = get_id(c);
    //printf("%d %d\n", id, c->current_cost);
    mylib_display_dec(id);
    mylib_display_char(' ');
    mylib_display_dec(c->current_cost);
    mylib_display_newline();
    if(id == start) break;
    c = c->parent_node;
  }
  
  //printf("\r\n");
  //printf("cost: %d", sum_of_cost);
  //printf("\r\n");
  mylib_display_newline();
  mylib_display_char('c');
  mylib_display_char('o');
  mylib_display_char('s');
  mylib_display_char('t');
  mylib_display_char(':');
  mylib_display_char(' ');
  mylib_display_dec(sum_of_cost);
  mylib_display_newline();
}

//------------------------------------------------------------------------------
void dijkstra()
{
  reset_xorshift();

  Uint start = *(volatile Uint*)(INFO_OFFSET + 0x0);
  Uint goal = *(volatile Uint*)(INFO_OFFSET + 0x4);

  Uint nedges = *(volatile Uint*)(INFO_OFFSET + 0x8);
  Uint nnodes = *(volatile Uint*)(INFO_OFFSET + 0xC);

  Uint mode = *(volatile Uint*)(INFO_OFFSET + 0x10);
  
  number_of_nodes = 0;
  number_of_edges = 0;
  node_index = 0;
  page_index = 0;

  node_array = (Node*) NODE_OFFSET;
  page_array = (Page*) PAGE_OFFSET;
  id_table = (Uint*) IDTB_OFFSET;
  addr_table = (Node**) ADTB_OFFSET;
  
  init_queue(&pqueue, MAX_NODES, (Heapelement*) HEAP_OFFSET);

  Uint i;
  for(i=0; i<MAX_NODES; i++){
    id_table[i] = 0;
    addr_table[i] = NULL;
  }

  Uint from, to, cost, prob;

  //add_edge(start, goal, 0x7fffffff);

  for(from=0; from<nnodes; from++){
    for(to=0; to<nnodes; to++){
      if(from == to) continue;
      cost = 1 + (xorshift() % 10000);
      prob = xorshift() % 1000;
      if(nedges * 1000 > nnodes * nnodes * prob){
        add_edge(from, to, cost);
        //add_edge(to, from, cost); // undirected graph
      }
    }
  }

  //printf("start:%d goal:%d\r\n", start, goal);
  //printf("num_nodes:%d num_edges:%d\r\n", number_of_nodes, number_of_edges);
  mylib_display_char('s');
  mylib_display_char('t');
  mylib_display_char('a');
  mylib_display_char('r');
  mylib_display_char('t');
  mylib_display_char(':');
  mylib_display_dec(start);
  mylib_display_char(' ');
  mylib_display_char('g');
  mylib_display_char('o');
  mylib_display_char('a');
  mylib_display_char('l');
  mylib_display_char(':');
  mylib_display_dec(goal);
  mylib_display_newline();

  mylib_display_char('n');
  mylib_display_char('u');
  mylib_display_char('m');
  mylib_display_char('_');
  mylib_display_char('n');
  mylib_display_char('o');
  mylib_display_char('d');
  mylib_display_char('e');
  mylib_display_char('s');
  mylib_display_char(':');
  mylib_display_dec(number_of_nodes);
  mylib_display_char(' ');
  mylib_display_char('n');
  mylib_display_char('u');
  mylib_display_char('m');
  mylib_display_char('_');
  mylib_display_char('e');
  mylib_display_char('d');
  mylib_display_char('g');
  mylib_display_char('e');
  mylib_display_char('s');
  mylib_display_char(':');
  mylib_display_dec(number_of_edges);
  mylib_display_newline();

  Uint sum_of_cost;
  Uint cycles;

  if(mode == 0){
    sum_of_cost = find_shortest_path(start, goal);
    cycles = 0;
  }else{
    Node* start_addr = get_node(start);
    Node* goal_addr = get_node(goal);
    *((volatile Uint*)(MMAP_DIJKSTRA)) = (volatile int) HEAP_OFFSET;
    *((volatile Uint*)(MMAP_DIJKSTRA)) = (volatile Uint) start_addr;
    *((volatile Uint*)(MMAP_DIJKSTRA)) = (volatile Uint) goal_addr;
    sum_of_cost = *((volatile Uint*)(MMAP_DIJKSTRA));
    cycles = *((volatile Uint*)(MMAP_DIJKSTRA));
  }

  my_sleep(1000);
  Xil_DCacheInvalidate();

  /*
  if(sum_of_cost < MAX_INT){
    walk_result(sum_of_cost, start, goal);
  }
  */
  mylib_display_char('c');
  mylib_display_char('o');
  mylib_display_char('s');
  mylib_display_char('t');
  mylib_display_char(':');
  mylib_display_dec(sum_of_cost);
  mylib_display_newline();

  //printf("exectuion cycle=%d\n", 0);
  mylib_display_char('c');
  mylib_display_char('y');
  mylib_display_char('c');
  mylib_display_char('l');
  mylib_display_char('e');
  mylib_display_char(':');
  mylib_display_dec(cycles);
  mylib_display_newline();

  mylib_display_char('E');
  mylib_display_char('N');
  mylib_display_char('D');

  reset_xorshift();

}

//------------------------------------------------------------------------------
void uart_loader()
{
  // Start Computation on PyCoRAM IP
  *((volatile Uint*)(MMAP_UART_LOADER)) = MMAP_MEMORY; // start address
  *((volatile Uint*)(MMAP_UART_LOADER)) = LOADER_SIZE; // size (byte)

  // Get Result
  volatile Uint start_address = *((volatile Uint*)(MMAP_UART_LOADER));
  mylib_display_hex(start_address);
  mylib_display_newline();
}

//------------------------------------------------------------------------------
void main_loop()
{
  uart_loader();
  dijkstra();
}

//------------------------------------------------------------------------------
int main() 
{
  Xil_ICacheEnable();
  Xil_DCacheEnable();

  while(1){ main_loop(); }

  Xil_DCacheDisable();
  Xil_ICacheDisable();
  
  return 0;
}

